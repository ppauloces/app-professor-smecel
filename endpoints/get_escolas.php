<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {

$input = json_decode(file_get_contents("php://input"), true);

if (!isset($input['codigo']) || empty($input['codigo'])) {
    echo json_encode(["status" => "error", "message" => "Código do professor é obrigatório"]);
    exit;
}

$codigo_professor = $input['codigo'];

try {
    // Buscar informações do professor
    $query_ProfLogado = "SELECT func_id_sec FROM smc_func WHERE func_id = :func_id";
    $stmt = $SmecelNovo->prepare($query_ProfLogado);
    $stmt->bindParam(':func_id', $codigo_professor, PDO::PARAM_INT);
    $stmt->execute();
    $professor = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$professor) {
        echo json_encode(["status" => "error", "message" => "Professor não encontrado"]);
        exit;
    }

    // Buscar ano letivo aberto
    $query_AnoLetivo = "SELECT ano_letivo_ano FROM smc_ano_letivo WHERE ano_letivo_id_sec = :id_sec AND ano_letivo_aberto = 'S' LIMIT 1";
    $stmt = $SmecelNovo->prepare($query_AnoLetivo);
    $stmt->bindParam(':id_sec', $professor['func_id_sec'], PDO::PARAM_INT);
    $stmt->execute();
    $anoLetivo = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$anoLetivo) {
        echo json_encode(["status" => "error", "message" => "Nenhum ano letivo aberto encontrado"]);
        exit;
    }

    // Buscar escolas vinculadas ao professor com base no ano letivo aberto
    $query_Escolas = "
        SELECT e.escola_id, e.escola_nome
        FROM smc_ch_lotacao_professor AS lp
        INNER JOIN smc_escola AS e ON e.escola_id = lp.ch_lotacao_escola
        INNER JOIN smc_turma AS t ON t.turma_id = lp.ch_lotacao_turma_id
        WHERE lp.ch_lotacao_professor_id = :professor_id 
          AND t.turma_ano_letivo = :ano_letivo
        GROUP BY e.escola_id
        ORDER BY e.escola_nome ASC";
    
    $stmt = $SmecelNovo->prepare($query_Escolas);
    $stmt->bindParam(':professor_id', $codigo_professor, PDO::PARAM_INT);
    $stmt->bindParam(':ano_letivo', $anoLetivo['ano_letivo_ano'], PDO::PARAM_INT);
    $stmt->execute();
    $escolas = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$escolas) {
        echo json_encode(["status" => "error", "message" => "Nenhuma escola encontrada"]);
        exit;
    }

    echo json_encode([
        "status" => "success",
        "ano_letivo" => $anoLetivo['ano_letivo_ano'],
        "escolas" => $escolas
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
