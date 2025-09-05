<?php
require_once('../../Connections/SmecelNovoPDO.php');

// Configuração de cabeçalhos para CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

session_start();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["status" => "error", "message" => "Método de requisição inválido."]);
    exit;
}

// Captura os dados do JSON enviado
$inputData = json_decode(file_get_contents("php://input"), true);

if (!isset($inputData['codigo'])) {
    echo json_encode(["status" => "error", "message" => "Código do professor não fornecido."]);
    exit;
}

$codigo = $inputData['codigo'];

try {
    // Busca as informações do professor no banco
    $query = "SELECT func_id, func_nome, func_email, func_matricula, func_cargo, func_lotacao, func_foto 
              FROM smc_func 
              WHERE func_id = :codigo";

    $stmt = $SmecelNovo->prepare($query);
    $stmt->bindParam(':codigo', $codigo, PDO::PARAM_INT);
    $stmt->execute();
    
    $professor = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($professor) {
        echo json_encode([
            "status" => "success",
            "professor" => $professor
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Professor não encontrado."
        ]);
    }
} catch (PDOException $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Erro ao buscar dados. Tente novamente mais tarde."
    ]);
}
?>
