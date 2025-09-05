<?php
header('Content-Type: application/json');
require_once('../../Connections/SmecelNovoPDO.php');

// Verifica se o código do professor foi enviado
if (!isset($_POST['codigo']) || empty($_POST['codigo'])) {
    echo json_encode(["status" => "error", "message" => "Código do professor é obrigatório"]);
    exit;
}

$codigo_professor = $_POST['codigo'];

try {
    // Buscar dados do professor
    $query_ProfLogado = "SELECT func_id, func_id_sec, func_nome, func_email, func_foto, func_sexo, func_data_nascimento 
                         FROM smc_func 
                         WHERE func_id = :func_id";
    $stmt = $SmecelNovo->prepare($query_ProfLogado);
    $stmt->bindParam(':func_id', $codigo_professor, PDO::PARAM_INT);
    $stmt->execute();
    $professor = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$professor) {
        echo json_encode(["status" => "error", "message" => "Professor não encontrado"]);
        exit;
    }

    // Buscar informações da secretaria
    $query_Secretaria = "SELECT sec_id, sec_nome, sec_prefeitura, sec_cep, sec_uf, sec_cidade, sec_endereco, sec_num, sec_bairro, 
                         sec_telefone1, sec_telefone2, sec_email, sec_nome_secretario, sec_bloqueada, sec_aviso_bloqueio, sec_logo 
                         FROM smc_sec 
                         WHERE sec_id = :sec_id";
    $stmt = $SmecelNovo->prepare($query_Secretaria);
    $stmt->bindParam(':sec_id', $professor['func_id_sec'], PDO::PARAM_INT);
    $stmt->execute();
    $secretaria = $stmt->fetch(PDO::FETCH_ASSOC);

    // Buscar vínculos do professor
    $query_Vinculos = "SELECT vinculo_id, vinculo_id_escola, vinculo_id_sec, vinculo_id_funcionario 
                       FROM smc_vinculo 
                       WHERE vinculo_id_funcionario = :func_id";
    $stmt = $SmecelNovo->prepare($query_Vinculos);
    $stmt->bindParam(':func_id', $professor['func_id'], PDO::PARAM_INT);
    $stmt->execute();
    $vinculos = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$vinculos) {
        echo json_encode(["status" => "error", "message" => "Nenhum vínculo encontrado"]);
        exit;
    }

    // Buscar ano letivo aberto
    $query_AnoLetivo = "SELECT ano_letivo_id, ano_letivo_ano, ano_letivo_inicio, ano_letivo_fim, 
                        ano_letivo_aberto, ano_letivo_id_sec, ano_letivo_resultado_final 
                        FROM smc_ano_letivo 
                        WHERE ano_letivo_id_sec = :id_sec AND ano_letivo_aberto = 'S' 
                        ORDER BY ano_letivo_ano DESC 
                        LIMIT 1";
    $stmt = $SmecelNovo->prepare($query_AnoLetivo);
    $stmt->bindParam(':id_sec', $vinculos['vinculo_id_sec'], PDO::PARAM_INT);
    $stmt->execute();
    $anoLetivo = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$anoLetivo) {
        echo json_encode(["status" => "error", "message" => "Nenhum ano letivo aberto encontrado"]);
        exit;
    }

    // Retorna os dados coletados
    echo json_encode([
        "status" => "success",
        "professor" => $professor,
        "secretaria" => $secretaria,
        "ano_letivo" => $anoLetivo
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
}
?>
