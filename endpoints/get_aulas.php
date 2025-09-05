<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents("php://input"), true);

    if (!isset($dataInput['professorId'], $dataInput['escolaId'], $dataInput['data'])) {
        echo json_encode(["status" => "error", "message" => "ID do professor, escola e data são obrigatórios"]);
        exit;
    }

    $professorId = $dataInput['professorId'];
    $escolaId = $dataInput['escolaId'];
    $data = $dataInput['data'];

    try {
        // Obter o dia da semana
        $semana = date("w", strtotime($data));

        $query = "
        SELECT 
            ch.ch_lotacao_aula AS numero_aula,
            d.disciplina_nome AS nome_disciplina,
            ch.ch_lotacao_turma_id AS turma_id,
            ch.ch_lotacao_disciplina_id AS disciplina_id
        FROM smc_ch_lotacao_professor AS ch
        INNER JOIN smc_turma AS t ON t.turma_id = ch.ch_lotacao_turma_id
        INNER JOIN smc_disciplina AS d ON d.disciplina_id = ch.ch_lotacao_disciplina_id
        WHERE ch.ch_lotacao_professor_id = :professorId 
          AND ch.ch_lotacao_escola = :escolaId
          AND ch.ch_lotacao_dia = :semana
        ORDER BY ch.ch_lotacao_aula ASC";    
        $stmt = $SmecelNovo->prepare($query);
        $stmt->bindValue(':professorId', $professorId, PDO::PARAM_INT);
        $stmt->bindValue(':escolaId', $escolaId, PDO::PARAM_INT);
        $stmt->bindValue(':semana', $semana, PDO::PARAM_INT);
        $stmt->execute();

        $aulas = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (!$aulas) {
            echo json_encode(["status" => "error", "message" => "Nenhuma aula encontrada para esta data."]);
            exit;
        }

        // Formatar a resposta com aula e disciplina juntas
        $aulasFormatadas = array_map(function ($aula) {
            return [
                "numero_aula" => $aula["numero_aula"],
                "formatted" => "{$aula["numero_aula"]}ª Aula - {$aula["nome_disciplina"]}",
                "turma_id" => $aula["turma_id"],
                "disciplina_id" => $aula["disciplina_id"]
            ];
        }, $aulas);

        echo json_encode(["status" => "success", "aulas" => $aulasFormatadas]);


    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método inválido. Use POST."]);
}
