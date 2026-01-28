<?php
// Inicia a sessão antes de tudo
if (!isset($_SESSION)) {
    session_start();
}

require_once('../../../../Connections/SmecelNovoPDO.php');
require_once('../../conf/session.php');

header('Content-Type: application/json; charset=utf-8');

// Obtém o usuário logado diretamente
$row_UsuarioLogado = null;
try {
    // Verifica se o usuário está logado na sessão
    if (!isset($_SESSION['MM_Username']) || empty($_SESSION['MM_Username'])) {
        echo json_encode(['success' => false, 'message' => 'Usuário não autenticado']);
        exit;
    }
    
    $query_ProfLogado = "SELECT func_id, func_id_sec, func_nome, func_email, func_foto, func_sexo, func_data_nascimento 
                         FROM smc_func 
                         WHERE func_id = :func_id";
    $stmt = $SmecelNovo->prepare($query_ProfLogado);
    $stmt->bindParam(':func_id', $colname_ProfLogado);
    $stmt->execute();
    $row_ProfLogado = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Verifica se encontrou o usuário
    if (!$row_ProfLogado || empty($row_ProfLogado['func_id'])) {
        echo json_encode(['success' => false, 'message' => 'Usuário não encontrado']);
        exit;
    }
    
} catch (PDOException $e) {
    error_log('Erro ao buscar usuário: ' . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Erro ao buscar dados do usuário']);
    exit;
}

$funcionario_id = (int)$row_ProfLogado['func_id'];
$secretaria_id = isset($row_ProfLogado['func_id_sec']) ? (int)$row_ProfLogado['func_id_sec'] : null;

try {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Verificar se a guia foi concluída
        $guia_cod = isset($_GET['guia_cod']) ? trim($_GET['guia_cod']) : '';
        
        if (empty($guia_cod)) {
            echo json_encode(['success' => false, 'message' => 'Código da guia não informado']);
            exit;
        }
        
        $stmt = $SmecelNovo->prepare("
            SELECT guia_concluida_id, guia_concluida_data 
            FROM smc_guias_concluidas 
            WHERE guia_concluida_cod_func = :funcionario_id 
            AND guia_concluida_cod_guia = :guia_cod 
            LIMIT 1
        ");
        $stmt->execute([
            ':funcionario_id' => $funcionario_id,
            ':guia_cod' => $guia_cod
        ]);
        
        $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($resultado) {
            echo json_encode([
                'success' => true,
                'concluida' => true,
                'data_conclusao' => $resultado['guia_concluida_data']
            ]);
        } else {
            echo json_encode([
                'success' => true,
                'concluida' => false
            ]);
        }
        
    } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Registrar conclusão da guia
        $guia_cod = isset($_POST['guia_cod']) ? trim($_POST['guia_cod']) : '';
        
        if (empty($guia_cod)) {
            echo json_encode(['success' => false, 'message' => 'Código da guia não informado']);
            exit;
        }
        
        // Verifica se já existe registro
        $stmtCheck = $SmecelNovo->prepare("
            SELECT guia_concluida_id 
            FROM smc_guias_concluidas 
            WHERE guia_concluida_cod_func = :funcionario_id 
            AND guia_concluida_cod_guia = :guia_cod 
            LIMIT 1
        ");
        $stmtCheck->execute([
            ':funcionario_id' => $funcionario_id,
            ':guia_cod' => $guia_cod
        ]);
        
        if ($stmtCheck->fetch()) {
            // Já existe, apenas retorna sucesso
            echo json_encode([
                'success' => true,
                'message' => 'Guia já estava registrada como concluída'
            ]);
        } else {
            // Insere novo registro
            $stmt = $SmecelNovo->prepare("
                INSERT INTO smc_guias_concluidas 
                (guia_concluida_cod_usuario, guia_concluida_cod_func, guia_concluida_cod_guia, guia_concluida_data, guia_concluida_sec) 
                VALUES (NULL, :funcionario_id, :guia_cod, NOW(), :secretaria_id)
            ");
            $stmt->execute([
                ':funcionario_id' => $funcionario_id,
                ':guia_cod' => $guia_cod,
                ':secretaria_id' => $secretaria_id
            ]);
            
            echo json_encode([
                'success' => true,
                'message' => 'Guia registrada como concluída com sucesso'
            ]);
        }
        
    } else {
        echo json_encode(['success' => false, 'message' => 'Método não permitido']);
    }
    
} catch (PDOException $e) {
    error_log('Erro ao processar guia concluída: ' . $e->getMessage());
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'message' => 'Erro ao processar solicitação'
    ]);
}
?>
