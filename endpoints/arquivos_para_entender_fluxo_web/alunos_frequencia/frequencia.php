<?php

if (!empty($_POST["batch"])) {

    require_once('../../../../Connections/SmecelNovoPDO.php');
    require_once('../../../../sistema/funcoes/ProfessorLogger.php');
    include "../../conf/session.php";

    $data = isset($_POST['data']) ? $_POST['data'] : null;
    $disciplina = isset($_POST['disciplina']) ? $_POST['disciplina'] : null;
    $turma = isset($_POST['turma']) ? $_POST['turma'] : null;
    $prof = isset($_POST['prof']) ? $_POST['prof'] : null;
    $ano = isset($_POST['ano']) ? $_POST['ano'] : null;
    $aulas = isset($_POST['aulas']) ? $_POST['aulas'] : [];
    $registros = isset($_POST['registros']) ? $_POST['registros'] : [];

    if (!is_array($aulas)) {
        $aulas = [$aulas];
    }
    if (!is_array($registros)) {
        $registros = [$registros];
    }

    if (empty($data) || empty($disciplina) || empty($turma) || empty($prof) || empty($ano) || empty($aulas) || empty($registros)) {
        echo json_encode(['status' => 'error', 'message' => 'Dados incompletos']);
        exit;
    }

    try {
        $SmecelNovo->beginTransaction();

        $query_Verifica = "
            SELECT faltas_alunos_id
            FROM smc_faltas_alunos
            WHERE faltas_alunos_matricula_id = :matricula
              AND faltas_alunos_data = :data
              AND faltas_alunos_numero_aula = :aula_numero";
        $stmtVerifica = $SmecelNovo->prepare($query_Verifica);

        $insertSQL = "
            INSERT INTO smc_faltas_alunos
                (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data)
            VALUES
                (:matricula, :disciplina, :aula_numero, :data)";
        $stmtInsert = $SmecelNovo->prepare($insertSQL);

        $totalInseridos = 0;

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
                        ':disciplina' => $disciplina,
                        ':aula_numero' => $aulaNumero,
                        ':data' => $data
                    ]);
                    $totalInseridos++;
                }
            }
        }

        $diaSemana = date("w", strtotime($data));
        $queryTurmaEscola = "
            SELECT turma_id_escola
            FROM smc_turma
            WHERE turma_id = :turma_id";
        $stmtTurmaEscola = $SmecelNovo->prepare($queryTurmaEscola);
        $stmtTurmaEscola->execute([':turma_id' => $turma]);
        $turmaEscola = $stmtTurmaEscola->fetch(PDO::FETCH_ASSOC);
        $escolaId = $turmaEscola ? $turmaEscola['turma_id_escola'] : null;

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
            ':professor' => $prof,
            ':turma' => $turma,
            ':disciplina' => $disciplina,
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
                ':professor' => $prof,
                ':escola' => $escolaId,
                ':turma' => $turma,
                ':disciplina' => $disciplina,
                ':lotacao' => $lotacoesPorAula[$aulaNumero],
                ':data' => $data,
                ':ip' => $ip,
                ':user_agent' => $userAgent
            ]);
        }

        $SmecelNovo->commit();

        try {
            $logger = new ProfessorLogger($SmecelNovo, $row_ProfLogado['func_id'], isset($row_ProfLogado['func_escola_id']) ? $row_ProfLogado['func_escola_id'] : null);
            $logger->logFrequencia('lancou', [
                'data_aula' => $data,
                'disciplina_id' => $disciplina,
                'turma_id' => $turma,
                'tipo_frequencia' => 'batch',
                'total_aulas' => count($aulas),
                'total_alunos' => count($registros),
                'total_inserts' => $totalInseridos
            ]);
        } catch (Exception $e) {
            error_log("Erro ao registrar log batch: " . $e->getMessage());
        }

        echo json_encode(['status' => 'ok', 'inseridos' => $totalInseridos]);
        exit;
    } catch (Exception $e) {
        $SmecelNovo->rollBack();
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
        exit;
    }
}

if (isset($_POST["matricula"])) {

    require_once('../../../../Connections/SmecelNovoPDO.php');
    require_once('../../../../sistema/funcoes/ProfessorLogger.php'); // Include the logger class
    include "../../conf/session.php"; // Include session to get professor info

    extract($_POST);

    // Verificar se a falta já está registrada
    $query_Verifica = "
        SELECT faltas_alunos_id, faltas_alunos_matricula_id, faltas_alunos_disciplina_id, 
               faltas_alunos_numero_aula, faltas_alunos_data 
        FROM smc_faltas_alunos 
        WHERE faltas_alunos_matricula_id = :matricula AND faltas_alunos_data = :data AND faltas_alunos_numero_aula = :aula_numero";
    $stmt = $SmecelNovo->prepare($query_Verifica);
    $stmt->execute([
        ':matricula' => $matricula,
        ':data' => $data,
        ':aula_numero' => $aula_numero
    ]);
    $row_Verifica = $stmt->fetch(PDO::FETCH_ASSOC);

    if (empty($matricula)) {
        echo "<script>Swal.fire({ position: 'top-end', icon: 'error', title: 'Ops...', text: 'Isso não deveria ter ocorrido', showConfirmButton: false, timer: 1000 })</script>";
        exit;
    } elseif ($row_Verifica) {
        // Buscar informações da falta antes de deletar para o log
        $queryFaltaInfo = "
            SELECT fa.*, a.aluno_nome, d.disciplina_nome, t.turma_nome, t.turma_id_escola
            FROM smc_faltas_alunos fa
            INNER JOIN smc_vinculo_aluno va ON va.vinculo_aluno_id = fa.faltas_alunos_matricula_id
            INNER JOIN smc_aluno a ON a.aluno_id = va.vinculo_aluno_id_aluno
            INNER JOIN smc_disciplina d ON d.disciplina_id = fa.faltas_alunos_disciplina_id
            INNER JOIN smc_turma t ON t.turma_id = va.vinculo_aluno_id_turma
            WHERE fa.faltas_alunos_id = :falta_id
        ";
        $stmtFaltaInfo = $SmecelNovo->prepare($queryFaltaInfo);
        $stmtFaltaInfo->execute([':falta_id' => $row_Verifica['faltas_alunos_id']]);
        $faltaInfo = $stmtFaltaInfo->fetch(PDO::FETCH_ASSOC);

        // Deletar a falta existente
        $deleteSQL = "DELETE FROM smc_faltas_alunos WHERE faltas_alunos_id = :id";
        $stmt = $SmecelNovo->prepare($deleteSQL);
        $stmt->execute([':id' => $row_Verifica['faltas_alunos_id']]);

        if ($faltaInfo) {
            try {
                $logger = new ProfessorLogger($SmecelNovo, $row_ProfLogado['func_id'], $faltaInfo['turma_id_escola']);

                $logger->logFrequencia('editou', [
                    'registro_id' => $faltaInfo['faltas_alunos_id'],
                    'aluno_matricula_id' => $faltaInfo['faltas_alunos_matricula_id'],
                    'data_aula' => $faltaInfo['faltas_alunos_data'],
                    'aula_numero' => $faltaInfo['faltas_alunos_numero_aula'],
                    'disciplina_id' => $faltaInfo['faltas_alunos_disciplina_id'],
                    'turma_id' => $faltaInfo['turma_id'],
                    'tipo_frequencia' => 'remocao_falta'
                ]);
            } catch (Exception $e) {
                error_log("Erro ao registrar log de remoção de falta: " . $e->getMessage());
            }
        }

        echo "<script>Swal.fire({ position: 'top-end', icon: 'success', title: 'Falta excluída', text: '$aluno', showConfirmButton: false, timer: 1000 })</script>";
        exit;
    } else {
        if ($multi == "s") {
            // Registrar faltas para múltiplas aulas
            $query_Outras = "
                SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, 
                       ch_lotacao_turma_id, ch_lotacao_dia, ch_lotacao_aula, 
                       disciplina_id, turma_turno
                FROM smc_ch_lotacao_professor
                INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
                INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
                WHERE turma_ano_letivo = :ano 
                  AND ch_lotacao_dia = :dia 
                  AND ch_lotacao_professor_id = :prof 
                  AND ch_lotacao_turma_id = :turma
                ORDER BY turma_turno, ch_lotacao_aula ASC";

            $stmt = $SmecelNovo->prepare($query_Outras);
            $stmt->execute([
                ':ano' => $ano,
                ':dia' => $dia,
                ':prof' => $prof,
                ':turma' => $turma
            ]);

            $row_Outras = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $count = 0;
            $aulas_registradas = [];

            foreach ($row_Outras as $outra) {
                // Verificar se já existe falta para essa aula
                $query_Verifica = "
                    SELECT faltas_alunos_id 
                    FROM smc_faltas_alunos 
                    WHERE faltas_alunos_matricula_id = :matricula AND faltas_alunos_data = :data AND faltas_alunos_numero_aula = :aula_numero";

                $stmt = $SmecelNovo->prepare($query_Verifica);
                $stmt->execute([
                    ':matricula' => $matricula,
                    ':data' => $data,
                    ':aula_numero' => $outra['ch_lotacao_aula']
                ]);

                if (!$stmt->fetch()) {
                    $insertSQL = "
                        INSERT INTO smc_faltas_alunos (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data) 
                        VALUES (:matricula, :disciplina, :aula_numero, :data)";

                    $stmt = $SmecelNovo->prepare($insertSQL);
                    $stmt->execute([
                        ':matricula' => $matricula,
                        ':disciplina' => $outra['ch_lotacao_disciplina_id'],
                        ':aula_numero' => $outra['ch_lotacao_aula'],
                        ':data' => $data
                    ]);

                    $count++;
                    $aulas_registradas[] = $outra['ch_lotacao_aula'];
                }
            }

            if ($count > 0) {
                try {
                    // Buscar informações do aluno e turma
                    $queryAlunoInfo = "
                        SELECT va.vinculo_aluno_id, t.turma_id, t.turma_id_escola
                        FROM smc_vinculo_aluno va
                        INNER JOIN smc_turma t ON t.turma_id = va.vinculo_aluno_id_turma
                        WHERE va.vinculo_aluno_id = :matricula_id
                    ";
                    $stmtAlunoInfo = $SmecelNovo->prepare($queryAlunoInfo);
                    $stmtAlunoInfo->execute([':matricula_id' => $matricula]);
                    $alunoInfo = $stmtAlunoInfo->fetch(PDO::FETCH_ASSOC);

                    if ($alunoInfo) {
                        $logger = new ProfessorLogger($SmecelNovo, $row_ProfLogado['func_id'], $alunoInfo['turma_id_escola']);

                        $logger->logFrequencia('lancou', [
                            'aluno_matricula_id' => $alunoInfo['vinculo_aluno_id'],
                            'data_aula' => $data,
                            'aula_numero' => $aula_numero,
                            'disciplina_id' => $disciplina,
                            'turma_id' => $alunoInfo['turma_id'],
                            'tipo_frequencia' => 'multiplas_aulas',
                            'aulas_registradas' => $count,
                            'total_aulas' => count($row_Outras)
                        ]);
                    }
                } catch (Exception $e) {
                    error_log("Erro ao registrar log de frequência múltipla: " . $e->getMessage());
                }
            }

            echo "<script>Swal.fire({ position: 'top-end', icon: 'success', title: 'Falta(s) registrada(s)', text: '$aluno', showConfirmButton: false, timer: 1000 })</script>";
            exit;
        } else {
            // Registrar falta para uma única aula
            $insertSQL = "
                INSERT INTO smc_faltas_alunos (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data) 
                VALUES (:matricula, :disciplina, :aula_numero, :data)";

            $stmt = $SmecelNovo->prepare($insertSQL);
            $stmt->execute([
                ':matricula' => $matricula,
                ':disciplina' => $disciplina,
                ':aula_numero' => $aula_numero,
                ':data' => $data
            ]);

             // REGISTRAR LOG DE FREQUÊNCIA ÚNICA (OTIMIZADO)
             try {
                // Buscar informações do aluno e turma
                $queryAlunoInfo = "
                    SELECT va.vinculo_aluno_id, t.turma_id, t.turma_id_escola
                    FROM smc_vinculo_aluno va
                    INNER JOIN smc_turma t ON t.turma_id = va.vinculo_aluno_id_turma
                    WHERE va.vinculo_aluno_id = :matricula_id
                ";
                $stmtAlunoInfo = $SmecelNovo->prepare($queryAlunoInfo);
                $stmtAlunoInfo->execute([':matricula_id' => $matricula]);
                $alunoInfo = $stmtAlunoInfo->fetch(PDO::FETCH_ASSOC);

                if ($alunoInfo) {
                    $logger = new ProfessorLogger($SmecelNovo, $row_ProfLogado['func_id'], $alunoInfo['turma_id_escola']);

                    $logger->logFrequencia('lancou', [
                        'aluno_matricula_id' => $alunoInfo['vinculo_aluno_id'],
                        'data_aula' => $data,
                        'aula_numero' => $aula_numero,
                        'disciplina_id' => $disciplina,
                        'turma_id' => $alunoInfo['turma_id'],
                        'tipo_frequencia' => 'aula_unica'
                    ]);
                }
            } catch (Exception $e) {
                error_log("Erro ao registrar log de frequência única: " . $e->getMessage());
            }

            echo "<script>Swal.fire({ position: 'top-end', icon: 'success', title: 'Falta registrada', text: '$aluno', showConfirmButton: false, timer: 1000 })</script>";
            exit;
        }
    }
} else {
    echo "Como é que você veio parar aqui?<br>";

    function get_client_ip()
    {
        $ipaddress = '';
        if (isset($_SERVER['HTTP_CLIENT_IP']))
            $ipaddress = $_SERVER['HTTP_CLIENT_IP'];
        else if (isset($_SERVER['HTTP_X_FORWARDED_FOR']))
            $ipaddress = $_SERVER['HTTP_X_FORWARDED_FOR'];
        else if (isset($_SERVER['REMOTE_ADDR']))
            $ipaddress = $_SERVER['REMOTE_ADDR'];
        else
            $ipaddress = 'UNKNOWN';
        return $ipaddress;
    }

    echo get_client_ip();

    header("Location:../../index.php?err");
}
?>
