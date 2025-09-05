<?php

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents("php://input"), true);

    if (!isset($dataInput['professorId'], $dataInput['escolaId'], $dataInput['turmaId'], $dataInput['data'])) {
        echo json_encode(["status" => "error", "message" => "Parâmetros obrigatórios ausentes."]);
        exit;
    }

    $professorId = $dataInput['professorId'];
    $escolaId = $dataInput['escolaId'];
    $turmaId = $dataInput['turmaId'];
    $data = $dataInput['data'];

    try {
        // Verifica qual é o dia da semana correspondente à data informada
        $semana = date("w", strtotime($data));

        // Obter o ano letivo atual
        $anoLetivo = date('Y');

        $query = "
            SELECT 
                ch_lotacao_id, 
                ch_lotacao_disciplina_id, 
                ch_lotacao_aula, 
                ch_lotacao_dia, 
                disciplina_nome 
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            WHERE ch_lotacao_professor_id = :professorId
              AND ch_lotacao_escola = :escolaId
              AND ch_lotacao_turma_id = :turmaId
              AND ch_lotacao_dia = :semana
              AND turma_ano_letivo = :anoLetivo
            ORDER BY ch_lotacao_aula ASC";

        $stmt = $SmecelNovo->prepare($query);
        $stmt->bindParam(':professorId', $professorId, PDO::PARAM_INT);
        $stmt->bindParam(':escolaId', $escolaId, PDO::PARAM_INT);
        $stmt->bindParam(':turmaId', $turmaId, PDO::PARAM_INT);
        $stmt->bindParam(':semana', $semana, PDO::PARAM_INT);
        $stmt->bindParam(':anoLetivo', $anoLetivo, PDO::PARAM_INT);
        $stmt->execute();
        $horarios = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (!$horarios) {
            echo json_encode(["status" => "error", "message" => "Nenhum horário encontrado para essa data."]);
            exit;
        }

        echo json_encode(["status" => "success", "horarios" => $horarios]);

    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método de requisição inválido."]);
}
