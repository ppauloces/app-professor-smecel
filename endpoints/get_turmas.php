<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");
require_once('../../Connections/SmecelNovoPDO.php');


if ($_SERVER['REQUEST_METHOD'] === 'POST') {
// Verifica se os dados foram enviados corretamente
$input = json_decode(file_get_contents("php://input"), true);

if (!isset($input['codigo']) || !isset($input['escola']) || empty($input['codigo']) || empty($input['escola'])) {
    echo json_encode(["status" => "error", "message" => "Código do professor e escola são obrigatórios"]);
    exit;
}

// Filtra e sanitiza os inputs para maior segurança
$codigo_professor = filter_var($input['codigo'], FILTER_SANITIZE_NUMBER_INT);
$escola_id = filter_var($input['escola'], FILTER_SANITIZE_NUMBER_INT);

try {
    // Buscar o ano letivo aberto baseado na escola do professor
    $query_AnoLetivo = "
        SELECT ano_letivo_ano 
        FROM smc_ano_letivo 
        WHERE ano_letivo_aberto = 'S' 
        AND ano_letivo_id_sec = (
            SELECT vinculo_id_sec 
            FROM smc_vinculo 
            WHERE vinculo_id_funcionario = :professor_id 
            LIMIT 1
        )
        LIMIT 1";

    $stmt = $SmecelNovo->prepare($query_AnoLetivo);
    $stmt->bindParam(':professor_id', $codigo_professor, PDO::PARAM_INT);
    $stmt->execute();
    $anoLetivo = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$anoLetivo) {
        echo json_encode(["status" => "error", "message" => "Nenhum ano letivo aberto encontrado"]);
        exit;
    }

    // Buscar turmas do professor na escola selecionada
    $query_Turmas = "
        SELECT t.turma_id, t.turma_nome, t.turma_turno, t.turma_ano_letivo
        FROM smc_ch_lotacao_professor AS lp
        INNER JOIN smc_turma AS t ON t.turma_id = lp.ch_lotacao_turma_id
        WHERE lp.ch_lotacao_professor_id = :professor_id 
          AND lp.ch_lotacao_escola = :escola_id 
          AND t.turma_ano_letivo = :ano_letivo
        GROUP BY t.turma_id
        ORDER BY t.turma_nome ASC";

    $stmt = $SmecelNovo->prepare($query_Turmas);
    $stmt->bindParam(':professor_id', $codigo_professor, PDO::PARAM_INT);
    $stmt->bindParam(':escola_id', $escola_id, PDO::PARAM_INT);
    $stmt->bindParam(':ano_letivo', $anoLetivo['ano_letivo_ano'], PDO::PARAM_INT);
    $stmt->execute();
    $turmas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$turmas) {
        echo json_encode(["status" => "error", "message" => "Nenhuma turma encontrada"]);
        exit;
    }

    echo json_encode([
        "status" => "success",
        "ano_letivo" => $anoLetivo['ano_letivo_ano'],
        "turmas" => $turmas
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
}
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Método de requisição inválido.'
    ]);
}
?>
