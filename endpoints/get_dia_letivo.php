<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Metodo de requisicao invalido.']);
    exit;
}

$input = json_decode(file_get_contents("php://input"), true);
if (!is_array($input) || empty($input)) {
    $input = $_POST;
}

$professorId = isset($input['professorId']) ? $input['professorId'] : (isset($input['codigo']) ? $input['codigo'] : null);
$escolaId = isset($input['escolaId']) ? $input['escolaId'] : (isset($input['escola']) ? $input['escola'] : null);
$data = isset($input['data']) ? $input['data'] : null;
$target = isset($input['target']) ? $input['target'] : 'frequencia';

if (empty($professorId) || empty($escolaId) || empty($data)) {
    echo json_encode(['status' => 'error', 'message' => 'Professor, escola e data sao obrigatorios.']);
    exit;
}

$professorId = filter_var($professorId, FILTER_SANITIZE_NUMBER_INT);
$escolaId = filter_var($escolaId, FILTER_SANITIZE_NUMBER_INT);
$data = date("Y-m-d", strtotime($data));
$semana = date("w", strtotime($data));

try {
    $stmtVinculo = $SmecelNovo->prepare("
        SELECT vinculo_id_sec
        FROM smc_vinculo
        WHERE vinculo_id_funcionario = :professor_id
          AND vinculo_id_escola = :escola_id
          AND vinculo_status = '1'
        LIMIT 1
    ");
    $stmtVinculo->execute([
        ':professor_id' => $professorId,
        ':escola_id' => $escolaId
    ]);
    $vinculo = $stmtVinculo->fetch(PDO::FETCH_ASSOC);

    if (!$vinculo) {
        echo json_encode(['status' => 'error', 'message' => 'Vinculo nao encontrado.']);
        exit;
    }

    $stmtAno = $SmecelNovo->prepare("
        SELECT ano_letivo_id, ano_letivo_ano
        FROM smc_ano_letivo
        WHERE ano_letivo_aberto = 'S'
          AND ano_letivo_id_sec = :sec_id
        ORDER BY ano_letivo_ano DESC
        LIMIT 1
    ");
    $stmtAno->execute([':sec_id' => $vinculo['vinculo_id_sec']]);
    $anoLetivo = $stmtAno->fetch(PDO::FETCH_ASSOC);

    if (!$anoLetivo) {
        echo json_encode(['status' => 'error', 'message' => 'Nenhum ano letivo aberto encontrado.']);
        exit;
    }

    $calendarioPadraoId = null;
    $stmtCalPadrao = $SmecelNovo->prepare("
        SELECT cal_id
        FROM smc_calendario
        WHERE cal_id_sec = :sec_id
          AND cal_padrao = 1
          AND cal_ano_letivo_id = :ano_letivo_id
        LIMIT 1
    ");
    $stmtCalPadrao->execute([
        ':sec_id' => $vinculo['vinculo_id_sec'],
        ':ano_letivo_id' => $anoLetivo['ano_letivo_id']
    ]);
    $rowCalPadrao = $stmtCalPadrao->fetch(PDO::FETCH_ASSOC);
    if ($rowCalPadrao) {
        $calendarioPadraoId = (int) $rowCalPadrao['cal_id'];
    }

    $filtraData = in_array($target, ['aulas', 'frequencia', 'planejamento'], true) ? 1 : 0;

    if ($target === 'rendimento') {
        $queryTurmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
                   ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
                   turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
                   COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
                   CASE turma_turno
                   WHEN 0 THEN 'INTEGRAL'
                   WHEN 1 THEN 'MATUTINO'
                   WHEN 2 THEN 'VESPERTINO'
                   WHEN 3 THEN 'NOTURNO'
                   END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo
              AND ch_lotacao_escola = :escola
              AND ch_lotacao_professor_id = :professor
            GROUP BY ch_lotacao_turma_id
            ORDER BY turma_turno ASC";
        $stmtTurmas = $SmecelNovo->prepare($queryTurmas);
        $stmtTurmas->execute([
            ':ano_letivo' => $anoLetivo['ano_letivo_ano'],
            ':escola' => $escolaId,
            ':professor' => $professorId
        ]);
    } else {
        $queryTurmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
                   ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
                   turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
                   COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
                   CASE turma_turno
                   WHEN 0 THEN 'INTEGRAL'
                   WHEN 1 THEN 'MATUTINO'
                   WHEN 2 THEN 'VESPERTINO'
                   WHEN 3 THEN 'NOTURNO'
                   END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo
              AND ch_lotacao_escola = :escola
              AND ch_lotacao_professor_id = :professor
              AND ch_lotacao_dia = :semana
            ORDER BY turma_turno, ch_lotacao_aula ASC";
        $stmtTurmas = $SmecelNovo->prepare($queryTurmas);
        $stmtTurmas->execute([
            ':ano_letivo' => $anoLetivo['ano_letivo_ano'],
            ':escola' => $escolaId,
            ':professor' => $professorId,
            ':semana' => $semana
        ]);
    }

    $turmasAll = $stmtTurmas->fetchAll(PDO::FETCH_ASSOC);
    $turmas = [];
    $turmasOcultas = 0;

    $diaLetivo = false;
    $diaClassificacao = 'NAO_LETIVO';
    $tipoCalendarioNome = '';
    $descricaoCalendario = '';
    $mensagemNaoLetivo = '';

    if ($filtraData == 1 && !empty($turmasAll)) {
        $calendariosUnicos = [];
        foreach ($turmasAll as $turma) {
            $calId = !empty($turma['matriz_calendario_id']) && $turma['matriz_calendario_id'] > 0
                ? (int) $turma['matriz_calendario_id']
                : $calendarioPadraoId;
            if ($calId !== null && !in_array($calId, $calendariosUnicos, true)) {
                $calendariosUnicos[] = $calId;
            }
        }

        $calendariosLetivos = [];
        $calendariosInfo = [];

        if (!empty($calendariosUnicos)) {
            try {
                $placeholders = implode(',', array_fill(0, count($calendariosUnicos), '?'));
                $stmtDias = $SmecelNovo->prepare("
                    SELECT ce.ce_calendario_id, ce.ce_tipo, ce.ce_descricao,
                           ct.ct_nome, ct.ct_e_dia_letivo, ct.ct_e_sabado_letivo
                    FROM smc_calendario_escolar ce
                    INNER JOIN smc_calendario_tipo ct ON ct.ct_id = ce.ce_tipo
                    WHERE ce.ce_id_sec = ?
                      AND ce.ce_data = ?
                      AND ce.ce_calendario_id IN ($placeholders)
                      AND ct.ct_ativo = 1
                ");
                $params = array_merge([$vinculo['vinculo_id_sec'], $data], $calendariosUnicos);
                $stmtDias->execute($params);
                $rowsDias = $stmtDias->fetchAll(PDO::FETCH_ASSOC);

                foreach ($rowsDias as $rowDia) {
                    $calId = (int) $rowDia['ce_calendario_id'];
                    $eDiaLetivo = !empty($rowDia['ct_e_dia_letivo']);
                    $eSabadoLetivo = !empty($rowDia['ct_e_sabado_letivo']);

                    $calendariosInfo[$calId] = [
                        'tipo' => (int) $rowDia['ce_tipo'],
                        'tipo_nome' => (string) $rowDia['ct_nome'],
                        'descricao' => (string) $rowDia['ce_descricao'],
                        'e_letivo' => $eDiaLetivo || $eSabadoLetivo,
                        'e_sabado_letivo' => $eSabadoLetivo
                    ];

                    if ($eDiaLetivo || $eSabadoLetivo) {
                        $calendariosLetivos[] = $calId;
                    }
                }
            } catch (PDOException $e) {
                $calendariosLetivos = $calendariosUnicos;
            }
        }

        foreach ($turmasAll as $turma) {
            $calIdTurma = !empty($turma['matriz_calendario_id']) && $turma['matriz_calendario_id'] > 0
                ? (int) $turma['matriz_calendario_id']
                : $calendarioPadraoId;

            if (in_array($calIdTurma, $calendariosLetivos, true)) {
                $turmas[] = $turma;
            } else {
                $turmasOcultas++;
            }
        }

        $diaLetivo = count($turmas) > 0;

        if (!$diaLetivo && count($turmasAll) > 0) {
            $mensagemNaoLetivo = "Nenhuma turma com dia letivo nesta data. {$turmasOcultas} turma(s) oculta(s) por calendario.";
        } elseif (!$diaLetivo) {
            $mensagemNaoLetivo = "Nenhuma turma vinculada nesta data.";
        } else {
            $primeiroCalLetivo = !empty($calendariosLetivos) ? $calendariosLetivos[0] : null;
            if ($primeiroCalLetivo && isset($calendariosInfo[$primeiroCalLetivo])) {
                $info = $calendariosInfo[$primeiroCalLetivo];
                $tipoCalendarioNome = $info['tipo_nome'];
                $descricaoCalendario = $info['descricao'];
                $diaClassificacao = $info['e_sabado_letivo'] ? 'SABADO_LETIVO' : 'LETIVO';
            }
        }
    } else {
        $turmas = $turmasAll;
        $diaLetivo = true;
        $diaClassificacao = 'LETIVO';
    }

    echo json_encode([
        'status' => 'success',
        'data' => $data,
        'dia_letivo' => $diaLetivo,
        'dia_classificacao' => $diaClassificacao,
        'tipo_calendario' => $tipoCalendarioNome,
        'descricao_calendario' => $descricaoCalendario,
        'mensagem_nao_letivo' => $mensagemNaoLetivo,
        'turmas' => $turmas,
        'turmas_ocultas' => $turmasOcultas,
        'calendario_padrao_id' => $calendarioPadraoId
    ]);
} catch (PDOException $e) {
    echo json_encode(['status' => 'error', 'message' => 'Erro no servidor: ' . $e->getMessage()]);
}
?>
