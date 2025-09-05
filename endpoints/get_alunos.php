<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");
require_once('../../Connections/SmecelNovoPDO.php');


if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Capturando os dados corretamente
    $dataInput = json_decode(file_get_contents('php://input'), true);


    $professorId = isset($dataInput['professorId']) ? $dataInput['professorId'] : null;
    $turmaId = isset($dataInput['turma']) ? $dataInput['turma'] : null;
    $disciplinaId = isset($dataInput['disciplina']) ? $dataInput['disciplina'] : null;
    $data = isset($dataInput['data']) ? $dataInput['data'] : null;
    $aulaNumero = isset($dataInput['aulaNumero']) ? $dataInput['aulaNumero'] : null;

    if (!$professorId || !$turmaId || !$disciplinaId || !$data) {
        echo json_encode(["status" => "error", "message" => "Código do professor, turma, disciplina e data são obrigatórios"]);
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


        // Consulta informações da turma e disciplina
        $query_Aula = "
        SELECT p.ch_lotacao_id, p.ch_lotacao_disciplina_id, p.ch_lotacao_turma_id, p.ch_lotacao_dia, p.ch_lotacao_aula, 
               d.disciplina_id, d.disciplina_nome, t.turma_id, t.turma_nome, t.turma_turno
        FROM smc_ch_lotacao_professor p
        INNER JOIN smc_disciplina d ON d.disciplina_id = p.ch_lotacao_disciplina_id
        INNER JOIN smc_turma t ON t.turma_id = p.ch_lotacao_turma_id
        WHERE p.ch_lotacao_professor_id = :professorId 
          AND p.ch_lotacao_turma_id = :turmaId
          AND p.ch_lotacao_disciplina_id = :disciplinaId
          AND t.turma_ano_letivo = :anoLetivo";

        $stmt = $SmecelNovo->prepare($query_Aula);
        $stmt->bindParam(':professorId', $professorId, PDO::PARAM_INT);
        $stmt->bindParam(':turmaId', $turmaId, PDO::PARAM_INT);
        $stmt->bindParam(':disciplinaId', $disciplinaId, PDO::PARAM_INT);
        $stmt->bindParam(':anoLetivo', $anoLetivo, PDO::PARAM_INT);
        $stmt->execute();

        $aula = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$aula) {
            echo json_encode(["status" => "error", "message" => "Nenhuma aula encontrada para essa turma e disciplina"]);
            exit;
        }

        // Consulta alunos da turma e verificar faltas
        $query_Alunos = "
SELECT 
    a.aluno_id, 
    a.aluno_nome, 
    va.vinculo_aluno_id, 
    va.vinculo_aluno_situacao,
    CASE 
        WHEN f.faltas_alunos_id IS NOT NULL THEN 1  -- 1 para com falta
        ELSE 0  -- 0 para sem falta
    END AS falta
FROM smc_vinculo_aluno va
INNER JOIN smc_aluno a ON a.aluno_id = va.vinculo_aluno_id_aluno
LEFT JOIN smc_faltas_alunos f 
    ON f.faltas_alunos_matricula_id = va.vinculo_aluno_id
    AND f.faltas_alunos_disciplina_id = :disciplinaId
    AND f.faltas_alunos_numero_aula = :aulaNumero
    AND f.faltas_alunos_data = :data
WHERE va.vinculo_aluno_id_turma = :turmaId
  AND va.vinculo_aluno_ano_letivo = :anoLetivo 
  AND va.vinculo_aluno_situacao = 1
ORDER BY a.aluno_nome ASC";
$stmt = $SmecelNovo->prepare($query_Alunos);
$stmt->bindParam(':turmaId', $turmaId, PDO::PARAM_INT);
$stmt->bindParam(':disciplinaId', $disciplinaId, PDO::PARAM_INT);
$stmt->bindParam(':aulaNumero', $aulaNumero, PDO::PARAM_INT);
$stmt->bindParam(':data', $data, PDO::PARAM_STR);
$stmt->bindParam(':anoLetivo', $anoLetivo, PDO::PARAM_INT);
$stmt->execute();

        $alunos = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (!$alunos) {
            echo json_encode(["status" => "error", "message" => "Nenhum aluno encontrado para esta turma"]);
            exit;
        }


        // Retorno da API com presença ajustada
        echo json_encode([
            "status" => "success",
            "ano_letivo" => $anoLetivo,
            "turma" => [
                "nome" => $aula['turma_nome'],
                "turno" => $aula['turma_turno']
            ],
            "disciplina" => [
                "nome" => $aula['disciplina_nome']
            ],
            "alunos" => $alunos
        ]);

    } catch (PDOException $e) {
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método inválido"]);
}
?>