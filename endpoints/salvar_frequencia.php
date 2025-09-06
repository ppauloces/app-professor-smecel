<?php

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');

// Log para debug
error_log("🔥 salvar_frequencia.php CHAMADO - " . date('Y-m-d H:i:s'));

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents("php://input"), true);
    error_log("🔥 Dados recebidos: " . json_encode($dataInput));

    if (!isset($dataInput['professorId'], $dataInput['turmaId'], $dataInput['aulaNumero'], $dataInput['data'], $dataInput['disciplinaId'], $dataInput['presencas'])) {
        echo json_encode(["status" => "error", "message" => "Todos os campos obrigatórios devem ser preenchidos."]);
        exit;
    }

    $professorId = (int)$dataInput['professorId'];
    $turmaId = (int)$dataInput['turmaId'];
    $aulaId = (int)$dataInput['aulaNumero'];
    $data = $dataInput['data'];
    $disciplinaId = (int)$dataInput['disciplinaId'];
    $presencas = $dataInput['presencas'];

    try {
        $SmecelNovo->beginTransaction();
        error_log("🔄 Iniciando transação para processar " . count($presencas) . " presenças");

        foreach ($presencas as $index => $presenca) {
            $alunoId = (int)$presenca['aluno_id'];
            // Aceita boolean, 0/1, 'true'/'false'
            $presente = filter_var($presenca['presente'], FILTER_VALIDATE_BOOLEAN);
            
            error_log("🔍 Processando aluno #$index: ID=$alunoId presente=" . ($presente ? 'true' : 'false'));

            // Verificar se a falta já está registrada
            $query_Verifica = "
                SELECT faltas_alunos_id 
                FROM smc_faltas_alunos 
                WHERE faltas_alunos_matricula_id = :aluno_id 
                  AND faltas_alunos_data = :data 
                  AND faltas_alunos_numero_aula = :aula_numero
                  AND faltas_alunos_disciplina_id = :disciplina_id";

            $stmt = $SmecelNovo->prepare($query_Verifica);
            $stmt->execute([
                ':aluno_id' => $alunoId,
                ':data' => $data,
                ':aula_numero' => $aulaId,
                ':disciplina_id' => $disciplinaId,
            ]);

            $row_Verifica = $stmt->fetch(PDO::FETCH_ASSOC);
            error_log("🔍 Query verificação: aluno=$alunoId data=$data aula=$aulaId disc=$disciplinaId - resultado: " . ($row_Verifica ? 'ENCONTRADO id=' . $row_Verifica['faltas_alunos_id'] : 'NÃO ENCONTRADO'));

            if ($presente) {
                // Se estiver presente e já tiver uma falta registrada, excluir a falta
                if ($row_Verifica) {
                    $deleteSQL = "DELETE FROM smc_faltas_alunos WHERE faltas_alunos_id = :id";
                    $stmt = $SmecelNovo->prepare($deleteSQL);
                    $stmt->execute([':id' => $row_Verifica['faltas_alunos_id']]);
                    error_log("🗑️ DELETE falta: aluno=$alunoId data=$data aula=$aulaId disc=$disciplinaId rows=".$stmt->rowCount());
                } else {
                    error_log("✅ Aluno $alunoId já estava presente (sem falta registrada)");
                }
            } else {
                // Se estiver ausente - SEMPRE processar a falta
                if (!$row_Verifica) {
                    // Não tem falta, inserir nova
                    $insertSQL = "
                        INSERT INTO smc_faltas_alunos 
                        (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data) 
                        VALUES (:aluno_id, :disciplina_id, :aula_numero, :data)";

                    $stmt = $SmecelNovo->prepare($insertSQL);
                    $stmt->execute([
                        ':aluno_id' => $alunoId,
                        ':disciplina_id' => $disciplinaId,
                        ':aula_numero' => $aulaId,
                        ':data' => $data
                    ]);
                    error_log("✅ INSERT falta: aluno=$alunoId data=$data aula=$aulaId disc=$disciplinaId rows=".$stmt->rowCount()." id=".$SmecelNovo->lastInsertId());
                } else {
                    // Já tem falta, mas vamos garantir que está marcada corretamente
                    error_log("⚠️ Aluno $alunoId já tinha falta registrada (id=" . $row_Verifica['faltas_alunos_id'] . ") - mantendo");
                }
            }
        }

        $SmecelNovo->commit();
        echo json_encode(["status" => "success", "message" => "Frequência registrada com sucesso."]);
    } catch (PDOException $e) {
        $SmecelNovo->rollBack();
        echo json_encode(["status" => "error", "message" => "Erro ao registrar a chamada: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método de requisição inválido."]);
}
?>
