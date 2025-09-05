<?php
// Exibir erros para depuração (remova em produção)
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Configuração do cabeçalho para CORS e JSON
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Verifica se a requisição é do tipo POST
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Recebe os dados enviados via JSON
    $inputData = json_decode(file_get_contents("php://input"), true);

    if (!$inputData || !isset($inputData['codigo'], $inputData['email'], $inputData['senha'])) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Todos os campos são obrigatórios.'
        ]);
        exit;
    }

    $codigo = trim($inputData['codigo']);
    $email = trim($inputData['email']);
    $senha = trim($inputData['senha']);

    // Conectar ao banco de dados (substitua pelo seu código)
    require_once('../../Connections/SmecelNovoPDO.php');

    try {
        // Verifica login no banco
        $query = "SELECT func_id, func_email, func_senha, func_senha_ativa, func_usu_tipo 
                  FROM smc_func 
                  WHERE func_id = :codigo AND func_email = :email AND func_senha = :senha AND func_senha_ativa = '1'";

        $stmt = $SmecelNovo->prepare($query);
        $stmt->bindParam(':codigo', $codigo);
        $stmt->bindParam(':email', $email);
        $stmt->bindParam(':senha', $senha);
        $stmt->execute();
        
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user) {
            echo json_encode([
                'status' => 'success',
                'user' => [
                    'codigo' => $user['func_id'],
                    'email' => $user['func_email']
                ]
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Usuário ou senha inválidos.'
            ]);
        }
    } catch (PDOException $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Erro no servidor. Tente novamente mais tarde.'
        ]);
    }
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Método de requisição inválido.'
    ]);
}
?>
