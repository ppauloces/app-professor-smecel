<?php
ob_start();

set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

set_exception_handler(function ($e) {
    if (!headers_sent()) {
        http_response_code(500);
        header('Content-Type: application/json; charset=UTF-8');
    }
    echo json_encode(['status' => 'error', 'message' => 'Erro no servidor.']);
    if (ob_get_length()) {
        ob_end_flush();
    }
    exit;
});

register_shutdown_function(function () {
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=UTF-8');
        }
        if (ob_get_length() === 0) {
            echo json_encode(['status' => 'error', 'message' => 'Erro fatal no servidor.']);
        }
    }
    if (ob_get_length()) {
        ob_end_flush();
    }
});

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');
require_once('../../sistema/funcoes/ProfessorLogger.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents("php://input"), true);

    if (!is_array($dataInput)) {
        echo json_encode(["status" => "error", "message" => "JSON inválido."]);
        exit;
    }

    $professorId = isset($dataInput['professorId']) ? $dataInput['professorId'] : (isset($dataInput['prof']) ? $dataInput['prof'] : null);
    $turmaId = isset($dataInput['turmaId']) ? $dataInput['turmaId'] : (isset($dataInput['turma']) ? $dataInput['turma'] : null);
    $disciplinaId = isset($dataInput['disciplinaId']) ? $dataInput['disciplinaId'] : (isset($dataInput['disciplina']) ? $dataInput['disciplina'] : null);
    $data = isset($dataInput['data']) ? $dataInput['data'] : null;
    $ano = isset($dataInput['ano']) ? $dataInput['ano'] : null;

    $aulas = [];
    if (isset($dataInput['aulas'])) {
        $aulas = $dataInput['aulas'];
    } elseif (isset($dataInput['aulaNumero'])) {
        $aulas = [$dataInput['aulaNumero']];
    }
    if (!is_array($aulas)) {
        $aulas = [$aulas];
    }

    $registros = [];
    $presencas = [];
    if (isset($dataInput['registros'])) {
        $registros = $dataInput['registros'];
    } elseif (isset($dataInput['presencas'])) {
        $presencas = $dataInput['presencas'];
    }

    if (empty($professorId) || empty($turmaId) || empty($disciplinaId) || empty($data) || empty($aulas) || (empty($registros) && empty($presencas))) {
        echo json_encode(["status" => "error", "message" => "Todos os campos obrigatórios devem ser preenchidos."]);
        exit;
    }

    try {
        $SmecelNovo->beginTransaction();

        $insertSQL = "
            INSERT INTO smc_faltas_alunos 
                (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data) 
            VALUES 
                (:matricula, :disciplina, :aula_numero, :data)";
        $stmtInsert = $SmecelNovo->prepare($insertSQL);

        $query_Verifica = "
            SELECT faltas_alunos_id 
            FROM smc_faltas_alunos 
            WHERE faltas_alunos_matricula_id = :matricula 
              AND faltas_alunos_data = :data 
              AND faltas_alunos_numero_aula = :aula_numero";
        $stmtVerifica = $SmecelNovo->prepare($query_Verifica);

        $deleteSQL = "DELETE FROM smc_faltas_alunos WHERE faltas_alunos_id = :id";
        $stmtDelete = $SmecelNovo->prepare($deleteSQL);

        $totalInseridos = 0;
        $totalRemovidos = 0;

        if (!empty($registros)) {
            foreach ($registros as $reg) {
                if (empty($reg['matricula'])) {
                    continue;
                }
                foreach ($aulas as $aulaNumero) {
                    $stmtVerifica->execute([
                        ':matricula' => $reg['matricula'],
                        ':data' => $data,
                        ':aula_numero' => $aulaNumero
                    ]);

                    if (!$stmtVerifica->fetch()) {
                        $stmtInsert->execute([
                            ':matricula' => $reg['matricula'],
                            ':disciplina' => $disciplinaId,
                            ':aula_numero' => $aulaNumero,
                            ':data' => $data
                        ]);
                        $totalInseridos++;
                    }
                }
            }
        } else {
            foreach ($presencas as $presenca) {
                if (!isset($presenca['aluno_id'])) {
                    continue;
                }
                $alunoId = $presenca['aluno_id'];
                $presente = !empty($presenca['presente']);

                foreach ($aulas as $aulaNumero) {
                    $stmtVerifica->execute([
                        ':matricula' => $alunoId,
                        ':data' => $data,
                        ':aula_numero' => $aulaNumero
                    ]);
                    $row_Verifica = $stmtVerifica->fetch(PDO::FETCH_ASSOC);

                    if ($presente) {
                        if ($row_Verifica) {
                            $stmtDelete->execute([':id' => $row_Verifica['faltas_alunos_id']]);
                            $totalRemovidos++;
                        }
                    } else {
                        if (!$row_Verifica) {
                            $stmtInsert->execute([
                                ':matricula' => $alunoId,
                                ':disciplina' => $disciplinaId,
                                ':aula_numero' => $aulaNumero,
                                ':data' => $data
                            ]);
                            $totalInseridos++;
                        }
                    }
                }
            }
        }

        $queryTurma = "
            SELECT turma_id_escola, turma_ano_letivo
            FROM smc_turma
            WHERE turma_id = :turma_id";
        $stmtTurma = $SmecelNovo->prepare($queryTurma);
        $stmtTurma->execute([':turma_id' => $turmaId]);
        $turmaInfo = $stmtTurma->fetch(PDO::FETCH_ASSOC);
        $escolaId = $turmaInfo ? $turmaInfo['turma_id_escola'] : null;
        if (empty($ano) && $turmaInfo && !empty($turmaInfo['turma_ano_letivo'])) {
            $ano = $turmaInfo['turma_ano_letivo'];
        }

        if (!empty($ano)) {
            $diaSemana = date("w", strtotime($data));
            $queryLotacoes = "
                SELECT ch_lotacao_id, ch_lotacao_aula
                FROM smc_ch_lotacao_professor
                INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
                WHERE ch_lotacao_professor_id = :professor
                  AND ch_lotacao_turma_id = :turma
                  AND ch_lotacao_disciplina_id = :disciplina
                  AND ch_lotacao_dia = :dia
                  AND turma_ano_letivo = :ano";
            $stmtLotacoes = $SmecelNovo->prepare($queryLotacoes);
            $stmtLotacoes->execute([
                ':professor' => $professorId,
                ':turma' => $turmaId,
                ':disciplina' => $disciplinaId,
                ':dia' => $diaSemana,
                ':ano' => $ano
            ]);
            $lotacoes = $stmtLotacoes->fetchAll(PDO::FETCH_ASSOC);
            $lotacoesPorAula = [];
            foreach ($lotacoes as $lotacao) {
                $lotacoesPorAula[$lotacao['ch_lotacao_aula']] = $lotacao['ch_lotacao_id'];
            }

            $insertConfirmacao = "
                INSERT IGNORE INTO smc_frequencia_confirmacao
                    (conf_professor_id, conf_escola_id, conf_turma_id, conf_disciplina_id, conf_ch_lotacao_id, conf_data, conf_confirmado_em, conf_ip, conf_user_agent)
                VALUES
                    (:professor, :escola, :turma, :disciplina, :lotacao, :data, NOW(), :ip, :user_agent)";
            $stmtConfirmacao = $SmecelNovo->prepare($insertConfirmacao);
            $ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : null;
            $userAgent = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : null;

            foreach ($aulas as $aulaNumero) {
                if (!isset($lotacoesPorAula[$aulaNumero])) {
                    continue;
                }
                $stmtConfirmacao->execute([
                    ':professor' => $professorId,
                    ':escola' => $escolaId,
                    ':turma' => $turmaId,
                    ':disciplina' => $disciplinaId,
                    ':lotacao' => $lotacoesPorAula[$aulaNumero],
                    ':data' => $data,
                    ':ip' => $ip,
                    ':user_agent' => $userAgent
                ]);
            }
        }

        $SmecelNovo->commit();

        try {
            $logger = new ProfessorLogger($SmecelNovo, $professorId, $escolaId);
            $logger->logFrequencia('lancou', [
                'data_aula' => $data,
                'disciplina_id' => $disciplinaId,
                'turma_id' => $turmaId,
                'tipo_frequencia' => empty($registros) ? 'app_presencas' : 'batch',
                'total_aulas' => count($aulas),
                'total_alunos' => empty($registros) ? count($presencas) : count($registros),
                'total_inserts' => $totalInseridos,
                'total_remocoes' => $totalRemovidos
            ]);
        } catch (Exception $e) {
            error_log("Erro ao registrar log via API: " . $e->getMessage());
        }

        echo json_encode([
            "status" => "success",
            "message" => "Frequência registrada com sucesso.",
            "inseridos" => $totalInseridos,
            "removidos" => $totalRemovidos
        ]);
    } catch (PDOException $e) {
        $SmecelNovo->rollBack();
        echo json_encode(["status" => "error", "message" => "Erro ao registrar a chamada: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método de requisição inválido."]);
}
?>
