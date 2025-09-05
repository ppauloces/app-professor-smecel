<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");
require_once('../../Connections/SmecelNovoPDO.php');


if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    $input = json_decode(file_get_contents("php://input"), true);

    $professorId = isset($input['codigo']) ? filter_var($input['codigo'], FILTER_SANITIZE_NUMBER_INT) : null;
    $turmaId = isset($input['turma']) ? filter_var($input['turma'], FILTER_SANITIZE_NUMBER_INT) : null;

    if (!$professorId || !$turmaId) {
        echo json_encode(["status" => "error", "message" => "ID do professor e da turma são obrigatórios"]);
        exit;
    }

    try {
        // Buscar a secretaria do professor para obter o ano letivo correto
        $query_Secretaria = "
            SELECT vinculo_id_sec 
            FROM smc_vinculo 
            WHERE vinculo_id_funcionario = :professorId
            LIMIT 1";

        $stmt = $SmecelNovo->prepare($query_Secretaria);
        $stmt->bindParam(':professorId', $professorId, PDO::PARAM_INT);
        $stmt->execute();
        $secRow = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$secRow) {
            echo json_encode(["status" => "error", "message" => "Secretaria não encontrada para o professor"]);
            exit;
        }
        $secId = $secRow['vinculo_id_sec'];

        // Buscar o ano letivo aberto baseado na secretaria
        $query_AnoLetivo = "
            SELECT ano_letivo_ano 
            FROM smc_ano_letivo 
            WHERE ano_letivo_aberto = 'S' 
              AND ano_letivo_id_sec = :secId
            ORDER BY ano_letivo_ano DESC 
            LIMIT 1";

        $stmt = $SmecelNovo->prepare($query_AnoLetivo);
        $stmt->bindParam(':secId', $secId, PDO::PARAM_INT);
        $stmt->execute();
        $anoLetivoRow = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$anoLetivoRow) {
            echo json_encode(["status" => "error", "message" => "Nenhum ano letivo aberto encontrado"]);
            exit;
        }
        $anoLetivo = $anoLetivoRow['ano_letivo_ano'];

        // Buscar componentes curriculares (disciplinas) vinculados à turma e professor
        $query = "
            SELECT DISTINCT d.disciplina_id, d.disciplina_nome 
            FROM smc_ch_lotacao_professor AS p
            INNER JOIN smc_disciplina AS d ON d.disciplina_id = p.ch_lotacao_disciplina_id
            INNER JOIN smc_turma AS t ON t.turma_id = p.ch_lotacao_turma_id
            WHERE p.ch_lotacao_professor_id = :professorId
              AND p.ch_lotacao_turma_id = :turmaId
              AND t.turma_ano_letivo = :anoLetivo
            ORDER BY d.disciplina_nome ASC";

        $stmt = $SmecelNovo->prepare($query);
        $stmt->bindParam(':professorId', $professorId, PDO::PARAM_INT);
        $stmt->bindParam(':turmaId', $turmaId, PDO::PARAM_INT);
        $stmt->bindParam(':anoLetivo', $anoLetivo, PDO::PARAM_INT);
        $stmt->execute();

        $componentes = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (!$componentes) {
            echo json_encode(["status" => "error", "message" => "Nenhum componente encontrado para esta turma"]);
            exit;
        }

        echo json_encode([
            "status" => "success",
            "ano_letivo" => $anoLetivo,
            "data" => $componentes
        ]);

    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método inválido"]);
}
?>
