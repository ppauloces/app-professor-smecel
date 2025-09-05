<?php
// Debug simples para testar sessão
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');

try {
    session_start();
    
    echo json_encode([
        'session_username' => isset($_SESSION['MM_Username']) ? $_SESSION['MM_Username'] : 'não definido',
        'session_usu_sec' => isset($_SESSION['usu_sec']) ? $_SESSION['usu_sec'] : 'não definido',
        'session_vars' => array_keys($_SESSION)
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
}
?> 