<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Log para debug
error_log("DEBUG: get_schema.php acessado");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents('php://input'), true);
    error_log("DEBUG: Dados recebidos: " . json_encode($dataInput));
    
    $module = isset($dataInput['module']) ? $dataInput['module'] : null;
    
    if (!$module) {
        error_log("DEBUG: Módulo não fornecido");
        echo json_encode(["status" => "error", "message" => "Módulo é obrigatório"]);
        exit;
    }
    
    try {
        // Carregar o dicionário de dados específico do módulo
        $dictionaryPath = "../../sistema/secretaria/config/data_dictionary_{$module}.php";
        error_log("DEBUG: Tentando carregar: " . $dictionaryPath);
        
        if (!file_exists($dictionaryPath)) {
            error_log("DEBUG: Arquivo não encontrado: " . $dictionaryPath);
            echo json_encode(["status" => "error", "message" => "Dicionário de dados não encontrado para o módulo: {$module}"]);
            exit;
        }
        
        error_log("DEBUG: Arquivo encontrado, carregando...");
        $dictionary = require($dictionaryPath);
        
        // Validar estrutura do dicionário
        if (!isset($dictionary['tables']) || !is_array($dictionary['tables'])) {
            error_log("DEBUG: Estrutura do dicionário inválida");
            echo json_encode(["status" => "error", "message" => "Estrutura do dicionário inválida"]);
            exit;
        }
        
        error_log("DEBUG: Dicionário carregado com sucesso");
        
        // Retornar o schema formatado para o frontend
        $response = [
            "status" => "success",
            "module" => $module,
            "schema" => [
                "tables" => $dictionary['tables'],
                "relationships" => isset($dictionary['relationships']) ? $dictionary['relationships'] : [],
                "aggregations" => isset($dictionary['aggregations']) ? $dictionary['aggregations'] : []
            ]
        ];
        
        error_log("DEBUG: Resposta preparada, enviando...");
        echo json_encode($response);
        
    } catch (Exception $e) {
        error_log("DEBUG: Exceção capturada: " . $e->getMessage());
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    error_log("DEBUG: Método não é POST: " . $_SERVER['REQUEST_METHOD']);
    echo json_encode(["status" => "error", "message" => "Método inválido. Use POST"]);
}
?> 