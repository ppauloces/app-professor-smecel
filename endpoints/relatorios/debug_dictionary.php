<?php
header('Content-Type: application/json');
error_reporting(E_ALL);
ini_set('display_errors', 1);

try {
    echo json_encode(['status' => 'inicio', 'message' => 'Iniciando debug']);
    
    // Testar se o arquivo existe
    $dictionaryPath = "../../sistema/secretaria/config/data_dictionary_alunos.php";
    
    if (!file_exists($dictionaryPath)) {
        echo json_encode(['status' => 'error', 'message' => 'Arquivo não encontrado: ' . $dictionaryPath]);
        exit;
    }
    
    echo json_encode(['status' => 'arquivo_encontrado', 'path' => $dictionaryPath]);
    
    // Testar o require
    ob_start();
    $dictionary = require($dictionaryPath);
    $output = ob_get_clean();
    
    if ($output) {
        echo json_encode(['status' => 'output_detectado', 'output' => $output]);
        exit;
    }
    
    echo json_encode(['status' => 'dictionary_carregado', 'tables' => array_keys($dictionary['tables'])]);
    
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
} catch (Error $e) {
    echo json_encode(['status' => 'fatal_error', 'message' => $e->getMessage(), 'trace' => $e->getTraceAsString()]);
}
?> 