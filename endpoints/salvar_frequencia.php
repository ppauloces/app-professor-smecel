<?php

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents("php://input"), true);

    if (!isset($dataInput['professorId'], $dataInput['turmaId'], $dataInput['aulaNumero'], $dataInput['data'], $dataInput['disciplinaId'], $dataInput['presencas'])) {
        echo json_encode(["status" => "error", "message" => "Todos os campos obrigatórios devem ser preenchidos."]);
        exit;
    }

    $professorId = $dataInput['professorId'];
    $turmaId = $dataInput['turmaId'];
    $aulaId = $dataInput['aulaNumero'];
    $data = $dataInput['data'];
    $disciplinaId = $dataInput['disciplinaId'];
    $presencas = $dataInput['presencas'];

    try {
        $SmecelNovo->beginTransaction();

        foreach ($presencas as $presenca) {
            $alunoId = $presenca['aluno_id'];
            $presente = $presenca['presente'];

            // Verificar se a falta já está registrada
            $query_Verifica = "
                SELECT faltas_alunos_id 
                FROM smc_faltas_alunos 
                WHERE faltas_alunos_matricula_id = :aluno_id 
                  AND faltas_alunos_data = :data 
                  AND faltas_alunos_numero_aula = :aula_numero";

            $stmt = $SmecelNovo->prepare($query_Verifica);
            $stmt->execute([
                ':aluno_id' => $alunoId,
                ':data' => $data,
                ':aula_numero' => $aulaId
            ]);

            $row_Verifica = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($presente) {
                // Se estiver presente e já tiver uma falta registrada, excluir a falta
                if ($row_Verifica) {
                    $deleteSQL = "DELETE FROM smc_faltas_alunos WHERE faltas_alunos_id = :id";
                    $stmt = $SmecelNovo->prepare($deleteSQL);
                    $stmt->execute([':id' => $row_Verifica['faltas_alunos_id']]);
                }
            } else {
                // Se estiver ausente e não tiver registro, adicionar falta
                if (!$row_Verifica) {
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
