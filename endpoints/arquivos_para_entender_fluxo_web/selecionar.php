<?php require_once('../../Connections/SmecelNovoPDO.php'); ?>
<?php include "conf/session.php"; ?>
<?php include "fnc/anti_injection.php"; ?>

<?php
$target = "-1";
if (isset($_GET['target'])) {
    $target = anti_injection($_GET['target']);
}

// Query para escolas
$query_escolas = "
    SELECT 
    ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id, ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola,
    escola_id, escola_nome, turma_id, turma_nome, turma_turno, turma_ano_letivo
    FROM smc_ch_lotacao_professor
    INNER JOIN smc_escola ON escola_id = ch_lotacao_escola 
    INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id 
    WHERE ch_lotacao_professor_id = :professor_id AND turma_ano_letivo = " . ANO_LETIVO . "
    GROUP BY escola_id
    ORDER BY escola_nome ASC";
$stmt_escolas = $SmecelNovo->prepare($query_escolas);
$stmt_escolas->bindParam(':professor_id', $row_ProfLogado['func_id'], PDO::PARAM_INT);
$stmt_escolas->execute();
$escolas = $stmt_escolas->fetchAll(PDO::FETCH_ASSOC);
$row_escolas = reset($escolas);
$totalRows_escolas = count($escolas);

$colname_escola = "-1";
if (isset($_GET['escola'])) {
    $colname_escola = anti_injection($_GET['escola']);


    $query_validate_access = "
        SELECT 
            escola_id,
            (SELECT COUNT(*) 
             FROM smc_ch_lotacao_professor 
             WHERE ch_lotacao_professor_id = :professor_id 
             AND ch_lotacao_escola = :escola_id) AS has_lotacao,
            (SELECT COUNT(*) 
             FROM smc_vinculo 
             WHERE vinculo_id_escola = :escola_id 
             AND vinculo_id_funcionario = :professor_id 
             AND vinculo_status = '1') AS has_vinculo
        FROM smc_escola 
        WHERE escola_id = :escola_id";
    $stmt_validate = $SmecelNovo->prepare($query_validate_access);
    $stmt_validate->bindParam(':escola_id', $colname_escola, PDO::PARAM_INT);
    $stmt_validate->bindParam(':professor_id', $row_ProfLogado['func_id'], PDO::PARAM_INT);
    $stmt_validate->execute();
    $validation_result = $stmt_validate->fetch(PDO::FETCH_ASSOC);

    if (!$validation_result || $validation_result['has_lotacao'] == 0 || $validation_result['has_vinculo'] == 0) {
        die(header("Location: index.php?permissao"));
    }
}

// Query para escola específica
$query_escola = "
    SELECT escola_id, escola_id_sec, escola_nome, escola_cep, escola_endereco, escola_num, escola_bairro, escola_telefone1, escola_telefone2, 
           escola_email, escola_inep, escola_cnpj, escola_logo, escola_ue, escola_situacao, escola_localizacao, escola_ibge_municipio, 
           escola_tema, escola_unidade_executora, escola_caixa_ux_prestacao_contas, escola_libera_boletim 
    FROM smc_escola 
    WHERE escola_id = :escola_id";
$stmt_escola = $SmecelNovo->prepare($query_escola);
$stmt_escola->bindParam(':escola_id', $colname_escola, PDO::PARAM_INT);
$stmt_escola->execute();
$escola = $stmt_escola->fetchAll(PDO::FETCH_ASSOC);
$row_escola = reset($escola);
$totalRows_escola = count($escola);

// Query para vínculos
if (isset($_GET['escola']) && !empty($_GET['escola'])) {
    $query_vinculos = "
    SELECT 
    ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id, ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola,
    turma_id, turma_nome, turma_turno, turma_ano_letivo, 
    CASE turma_turno
    WHEN 0 THEN 'INT'
    WHEN 1 THEN 'MAT'
    WHEN 2 THEN 'VES'
    WHEN 3 THEN 'NOT'
    END AS turma_turno_nome 
    FROM smc_ch_lotacao_professor
    INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id 
    WHERE ch_lotacao_professor_id = :professor_id AND ch_lotacao_escola = :escola_id AND turma_ano_letivo = " . ANO_LETIVO . "
    GROUP BY ch_lotacao_turma_id
    ORDER BY turma_turno, turma_nome ASC";
    $stmt_vinculos = $SmecelNovo->prepare($query_vinculos);
    $stmt_vinculos->bindParam(':professor_id', $row_ProfLogado['func_id'], PDO::PARAM_INT);
    $stmt_vinculos->bindParam(':escola_id', $row_escola['escola_id'], PDO::PARAM_INT);
    $stmt_vinculos->execute();
    $vinculos = $stmt_vinculos->fetchAll(PDO::FETCH_ASSOC);
    $row_vinculos = reset($vinculos);
    $totalRows_vinculos = count($vinculos);

    if ($totalRows_vinculos == 0) {
        die(header("Location: index.php?permissao"));
    }
}
if (isset($_GET['data'])) {
    $data = anti_injection($_GET['data']);
    $semana = date("w", strtotime($data));
    $diasemana = array('Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sabado');
    $dia_semana_nome = $diasemana[$semana];
    $data = date("Y-m-d", strtotime($data));
} else {
    $data = date("Y-m-d");
    $semana = date("w", strtotime($data));
    $diasemana = array('Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sabado');
    $dia_semana_nome = $diasemana[$semana];
    $data = date("Y-m-d", strtotime($data));
}

// ====== BUSCAR CALENDÁRIO PADRÃO ======
$calendarioPadraoId = null;
try {
    $stmtCalPadrao = $SmecelNovo->prepare("
        SELECT cal_id FROM smc_calendario
        WHERE cal_id_sec = :sec_id AND cal_padrao = 1 AND cal_ano_letivo_id = :ano_letivo_id
        LIMIT 1
    ");
    $stmtCalPadrao->execute([
        ':sec_id' => SEC_ID,
        ':ano_letivo_id' => $row_AnoLetivo['ano_letivo_id']
    ]);
    $rowCalPadrao = $stmtCalPadrao->fetch(PDO::FETCH_ASSOC);
    if ($rowCalPadrao) {
        $calendarioPadraoId = (int) $rowCalPadrao['cal_id'];
    }
} catch (PDOException $e) {
    $calendarioPadraoId = null;
}

if (isset($_GET['escola'])) {
    $escola = anti_injection($_GET['escola']);
} else {
    $escola = "";
}

// Variáveis para o switch
$Turmas_All = [];
$aulaNum = 1;
$filtraData = 1;

switch ($target) {
    case "aulas":
        $link_target = "aulas.php";
        $nome_target = "REGISTRAR AULAS";
        $tabela_turma = "ch_lotacao_id";
        $query_Turmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
            ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
            turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
            COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
            CASE turma_turno
            WHEN 0 THEN 'INT'
            WHEN 1 THEN 'MAT'
            WHEN 2 THEN 'VES'
            WHEN 3 THEN 'NOT'
            END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo AND ch_lotacao_escola = :escola AND ch_lotacao_professor_id = :professor AND ch_lotacao_dia = :semana
            ORDER BY turma_turno, ch_lotacao_aula ASC";
        $stmt_Turmas = $SmecelNovo->prepare($query_Turmas);
        $stmt_Turmas->execute([
            ':ano_letivo' => $row_AnoLetivo['ano_letivo_ano'],
            ':escola' => $escola,
            ':professor' => $row_Vinculos['vinculo_id_funcionario'],
            ':semana' => $semana
        ]);
        $Turmas_All = $stmt_Turmas->fetchAll(PDO::FETCH_ASSOC);
        $aulaNum = 1;
        $filtraData = 1;
        break;

    case "frequencia":
        $link_target = "frequencia.php";
        $nome_target = "FREQUÊNCIA";
        $tabela_turma = "ch_lotacao_id";
        $query_Turmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
            ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
            turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
            COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
            CASE turma_turno
            WHEN 0 THEN 'INTEGRAL'
            WHEN 1 THEN 'MATUTINO'
            WHEN 2 THEN 'VESPERTINO'
            WHEN 3 THEN 'NOTURNO'
            END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo AND ch_lotacao_escola = :escola AND ch_lotacao_professor_id = :professor AND ch_lotacao_dia = :semana
            ORDER BY turma_turno, ch_lotacao_aula ASC";
        $stmt_Turmas = $SmecelNovo->prepare($query_Turmas);
        $stmt_Turmas->execute([
            ':ano_letivo' => $row_AnoLetivo['ano_letivo_ano'],
            ':escola' => $escola,
            ':professor' => $row_Vinculos['vinculo_id_funcionario'],
            ':semana' => $semana
        ]);
        $Turmas_All = $stmt_Turmas->fetchAll(PDO::FETCH_ASSOC);
        $aulaNum = 1;
        $filtraData = 1;
        break;

    case "planejamento":
        $link_target = "planejamento.php";
        $nome_target = "PLANEJAMENTO";
        $tabela_turma = "ch_lotacao_id";
        $query_Turmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
            ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
            turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
            COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
            CASE turma_turno
            WHEN 0 THEN 'INTEGRAL'
            WHEN 1 THEN 'MATUTINO'
            WHEN 2 THEN 'VESPERTINO'
            WHEN 3 THEN 'NOTURNO'
            END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo AND ch_lotacao_escola = :escola AND ch_lotacao_professor_id = :professor AND ch_lotacao_dia = :semana
            ORDER BY turma_turno, ch_lotacao_aula ASC";
        $stmt_Turmas = $SmecelNovo->prepare($query_Turmas);
        $stmt_Turmas->execute([
            ':ano_letivo' => $row_AnoLetivo['ano_letivo_ano'],
            ':escola' => $escola,
            ':professor' => $row_Vinculos['vinculo_id_funcionario'],
            ':semana' => $semana
        ]);
        $Turmas_All = $stmt_Turmas->fetchAll(PDO::FETCH_ASSOC);
        $aulaNum = 1;
        $filtraData = 1;
        break;

    case "rendimento":
        $link_target = "rendimento_notas_turma.php";
        $nome_target = "RENDIMENTO";
        $tabela_turma = "ch_lotacao_turma_id";
        $query_Turmas = "
            SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id,
            ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, turma_id, turma_nome,
            turma_ano_letivo, turma_turno, turma_matriz_id, disciplina_id, disciplina_nome, disciplina_nome_abrev,
            COALESCE(m.matriz_calendario_id, 0) AS matriz_calendario_id,
            CASE turma_turno
            WHEN 0 THEN 'INTEGRAL'
            WHEN 1 THEN 'MATUTINO'
            WHEN 2 THEN 'VESPERTINO'
            WHEN 3 THEN 'NOTURNO'
            END AS turma_turno_nome
            FROM smc_ch_lotacao_professor
            INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
            INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
            LEFT JOIN smc_matriz m ON m.matriz_id = turma_matriz_id
            WHERE turma_ano_letivo = :ano_letivo AND ch_lotacao_escola = :escola AND ch_lotacao_professor_id = :professor
            GROUP BY ch_lotacao_turma_id
            ORDER BY turma_turno ASC";
        $stmt_Turmas = $SmecelNovo->prepare($query_Turmas);
        $stmt_Turmas->execute([
            ':ano_letivo' => $row_AnoLetivo['ano_letivo_ano'],
            ':escola' => $escola,
            ':professor' => $row_Vinculos['vinculo_id_funcionario']
        ]);
        $Turmas_All = $stmt_Turmas->fetchAll(PDO::FETCH_ASSOC);
        $aulaNum = 0;
        $filtraData = 0;
        break;

    default:
        header("Location:index.php?err");
        exit;
}

// ====== VERIFICAÇÃO DE CALENDÁRIO POR TURMA (apenas se filtraData == 1) ======
$diaLetivo = false;
$tipoCalendarioNome = '';
$descricaoCalendario = '';
$diaClassificacao = 'NAO_LETIVO';
$mensagemNaoLetivo = '';
$Turmas = [];
$turmasOcultas = 0;

if ($filtraData == 1 && !empty($Turmas_All)) {
    // Coletar calendários únicos das turmas
    $calendariosUnicos = [];
    foreach ($Turmas_All as $turma) {
        $calId = !empty($turma['matriz_calendario_id']) && $turma['matriz_calendario_id'] > 0
            ? (int) $turma['matriz_calendario_id']
            : $calendarioPadraoId;
        if ($calId !== null && !in_array($calId, $calendariosUnicos)) {
            $calendariosUnicos[] = $calId;
        }
    }

    // Verificar quais calendários têm o dia como letivo
    $calendariosLetivos = [];
    $calendariosInfo = [];

    if (!empty($calendariosUnicos)) {
        try {
            $placeholders = implode(',', array_fill(0, count($calendariosUnicos), '?'));
            $stmtDias = $SmecelNovo->prepare("
                SELECT ce.ce_calendario_id, ce.ce_tipo, ce.ce_descricao,
                       ct.ct_nome, ct.ct_e_dia_letivo, ct.ct_e_sabado_letivo
                FROM smc_calendario_escolar ce
                INNER JOIN smc_calendario_tipo ct ON ct.ct_id = ce.ce_tipo
                WHERE ce.ce_id_sec = ?
                  AND ce.ce_data = ?
                  AND ce.ce_calendario_id IN ($placeholders)
                  AND ct.ct_ativo = 1
            ");
            $params = array_merge([SEC_ID, $data], $calendariosUnicos);
            $stmtDias->execute($params);
            $rowsDias = $stmtDias->fetchAll(PDO::FETCH_ASSOC);

            foreach ($rowsDias as $rowDia) {
                $calId = (int) $rowDia['ce_calendario_id'];
                $eDiaLetivo = !empty($rowDia['ct_e_dia_letivo']);
                $eSabadoLetivo = !empty($rowDia['ct_e_sabado_letivo']);

                $calendariosInfo[$calId] = [
                    'tipo' => (int) $rowDia['ce_tipo'],
                    'tipo_nome' => (string) $rowDia['ct_nome'],
                    'descricao' => (string) $rowDia['ce_descricao'],
                    'e_letivo' => $eDiaLetivo || $eSabadoLetivo,
                    'e_sabado_letivo' => $eSabadoLetivo
                ];

                if ($eDiaLetivo || $eSabadoLetivo) {
                    $calendariosLetivos[] = $calId;
                }
            }
        } catch (PDOException $e) {
            $calendariosLetivos = $calendariosUnicos;
        }
    }

    // Filtrar turmas - apenas onde o dia é letivo no calendário da matriz
    foreach ($Turmas_All as $turma) {
        $calIdTurma = !empty($turma['matriz_calendario_id']) && $turma['matriz_calendario_id'] > 0
            ? (int) $turma['matriz_calendario_id']
            : $calendarioPadraoId;

        if (in_array($calIdTurma, $calendariosLetivos)) {
            $Turmas[] = $turma;
        } else {
            $turmasOcultas++;
        }
    }

    // Determinar status geral do dia
    $diaLetivo = count($Turmas) > 0;

    if (!$diaLetivo && count($Turmas_All) > 0) {
        $mensagemNaoLetivo = "Nenhuma turma com dia letivo nesta data. {$turmasOcultas} turma(s) oculta(s) por calendário.";
    } elseif (!$diaLetivo) {
        $mensagemNaoLetivo = "Nenhuma turma vinculada nesta data.";
    } else {
        $primeiroCalLetivo = !empty($calendariosLetivos) ? $calendariosLetivos[0] : null;
        if ($primeiroCalLetivo && isset($calendariosInfo[$primeiroCalLetivo])) {
            $info = $calendariosInfo[$primeiroCalLetivo];
            $tipoCalendarioNome = $info['tipo_nome'];
            $descricaoCalendario = $info['descricao'];
            $diaClassificacao = $info['e_sabado_letivo'] ? 'SABADO_LETIVO' : 'LETIVO';
        }
    }
} else {
    // Sem filtro de data (ex: rendimento) - usa todas as turmas
    $Turmas = $Turmas_All;
    $diaLetivo = true;
}

$row_Turmas = reset($Turmas);
$totalRows_Turmas = count($Turmas);
?>

<!DOCTYPE html>
<html class="<?php echo TEMA; ?>" lang="pt-br">

<head>
    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=UA-117872281-1"></script>
    <script>
        window.dataLayer = window.dataLayer || [];
        function gtag() { dataLayer.push(arguments); }
        gtag('js', new Date());
        gtag('config', 'UA-117872281-1');
    </script>
    <title>PROFESSOR | <?php echo $row_ProfLogado['func_nome']; ?>| SMECEL - Sistema de Gestão Escolar</title>
    <meta charset="utf-8">
    <meta content="IE=edge,chrome=1" http-equiv="X-UA-Compatible">
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
    <meta name="mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <link rel="apple-touch-icon" sizes="180x180" href="https://www.smecel.com.br/apple-touch-icon.png">
    <link rel="icon" type="image/png" sizes="32x32" href="https://www.smecel.com.br/favicon-32x32.png">
    <link rel="icon" type="image/png" sizes="16x16" href="https://www.smecel.com.br/favicon-16x16.png">
    <link rel="manifest" href="https://www.smecel.com.br/site.webmanifest">
    <link rel="stylesheet" type="text/css" href="css/locastyle.css">
    <link rel="stylesheet" href="css/sweetalert2.min.css">
</head>

<body>
    <?php include_once "inc/navebar.php"; ?>
    <?php include_once "inc/sidebar.php"; ?>
    <main class="ls-main">
        <div class="container-fluid">
            <h1 class="ls-title-intro ls-ico-home"><?php echo $nome_target; ?></h1>
            <p><a href="index.php" class="ls-btn ls-ico-chevron-left">Voltar</a></p>

            <div class="ls-box-filter">
                <form action="selecionar.php" class="row">
                    <?php if ($filtraData == 1) { ?>
                        <label class="ls-label col-md-4 col-xs-12">
                            <b class="ls-label-text">MUDE A DATA (para chamada retroativa)</b>
                            <input type="date" name="data" class="" id="data" value="<?php echo $data; ?>"
                                autocomplete="off" onchange="this.form.submit()">
                            <p>Data definida: <?php echo date("d/m/Y", strtotime($data)); ?>
                                (<?php echo $dia_semana_nome; ?>)</p>
                        </label>
                    <?php } ?>

                    <input type="hidden" name="target" value="<?php echo $target; ?>">

                    <?php if ($totalRows_escola == 0) { ?>
                        <label class="ls-label col-md-12 col-xs-12">
                            <p>UNIDADE ESCOLAR:</p>
                            <p>
                                <?php
                                foreach ($escolas as $row_escolas) {
                                    $vinculo_q = "
                                        SELECT * FROM smc_vinculo 
                                        WHERE vinculo_id_escola = :escola_id 
                                        AND vinculo_id_funcionario = :func_id 
                                        AND vinculo_status = '1' 
                                        AND vinculo_acesso = 'N'";
                                    $stmt_vinculo = $SmecelNovo->prepare($vinculo_q);
                                    $stmt_vinculo->execute([
                                        ':escola_id' => $row_escolas['escola_id'],
                                        ':func_id' => $row_ProfLogado['func_id']
                                    ]);
                                    $vinculo = $stmt_vinculo->fetchAll(PDO::FETCH_ASSOC);
                                    $vinculo_row = reset($vinculo);
                                    $vinculo_total = count($vinculo);

                                    if ($vinculo_total == 0) {
                                        ?>
                                        <a class="ls-btn-primary ls-btn-lg ls-btn-block"
                                            href="selecionar.php?escola=<?php echo $row_escolas['escola_id']; ?>&target=<?php echo $target; ?>&data=<?php echo $data; ?>"><?php echo $row_escolas['escola_nome']; ?></a>
                                    <?php
                                    }
                                }
                                ?>
                            </p>
                        </label>
                    <?php } ?>

                    <!-- Status do Dia (Letivo/Não Letivo) -->
                    <label class="ls-label col-md-12 col-xs-12">
                        <?php if ($filtraData == 1): ?>
                            <?php if ($diaLetivo): ?>
                                <?php if ($diaClassificacao === 'SABADO_LETIVO'): ?>
                                    <div class="ls-alert-success"
                                        style="background-color: #FFF3E0; border-color: #FF9800; color: #000;">
                                        <strong>✓ Sábado Letivo</strong>
                                        <?php if ($tipoCalendarioNome): ?>
                                            - <?php echo htmlspecialchars($tipoCalendarioNome); ?>
                                        <?php endif; ?>
                                        <?php if ($descricaoCalendario): ?>
                                            <br><small><?php echo htmlspecialchars($descricaoCalendario); ?></small>
                                        <?php endif; ?>
                                    </div>
                                <?php else: ?>
                                    <div class="ls-alert-success">
                                        <strong>✓ Dia Letivo</strong>
                                        <?php if ($tipoCalendarioNome): ?>
                                            - <?php echo htmlspecialchars($tipoCalendarioNome); ?>
                                        <?php endif; ?>
                                        <?php if ($descricaoCalendario): ?>
                                            <br><small><?php echo htmlspecialchars($descricaoCalendario); ?></small>
                                        <?php endif; ?>
                                    </div>
                                <?php endif; ?>
                            <?php else: ?>
                                <div class="ls-alert-danger">
                                    <strong>✗ Dia Não Letivo</strong>
                                    <br><?php echo $mensagemNaoLetivo; ?>
                                    <br><small>Selecione uma data letiva para registrar frequência.</small>
                                </div>
                            <?php endif; ?>
                        <?php endif; ?>
                    </label>

                    <label class="ls-label col-md-12 col-xs-12">
                        <?php if ($totalRows_escola > 0) { ?>
                            <?php if ($totalRows_Turmas > 0 && $diaLetivo) { ?>
                                <div class="ls-alert-success"><strong>Escola selecionada:</strong>
                                    <?php echo $row_escola['escola_nome']; ?> (<a
                                        href="selecionar.php?target=<?php echo $target; ?>&data=<?php echo $data; ?>">Voltar</a>)
                                </div>
                            <?php } elseif ($totalRows_Turmas > 0 && !$diaLetivo) { ?>
                                <div class="ls-alert-warning"><strong>Atenção:</strong> Não é possível registrar
                                    <?php echo strtolower($nome_target); ?> em dias não letivos. (<a
                                        href="selecionar.php?target=<?php echo $target; ?>&data=<?php echo $data; ?>">Voltar</a>)
                                </div>
                            <?php } else { ?>
                                <div class="ls-alert-warning"><strong>Atenção:</strong> Nenhuma turma vinculada para esta data.
                                    (<a
                                        href="selecionar.php?target=<?php echo $target; ?>&data=<?php echo $data; ?>">Voltar</a>)
                                </div>
                            <?php } ?>
                        <?php } else { ?>
                            <div class="ls-alert-success"><strong>Selecione a Unidade Escolar</strong></div>
                        <?php } ?>
                    </label>

                    <div style="display:<?php if ($totalRows_Turmas == 0 || !$diaLetivo) { ?>none<?php } ?>">
                        <label class="ls-label col-md-12 col-xs-12">
                            <?php if ($totalRows_Turmas > 0 && $diaLetivo) { ?>
                                <p>AULAS:</p><br>
                                <div class="ls-group-btn">
                                    <?php
                                    foreach ($Turmas as $row_Turmas) {
                                        $query_MatrizDisciplinas = "
                                            SELECT matriz_disciplina_id, matriz_disciplina_id_matriz, matriz_disciplina_eixo, matriz_disciplina_id_disciplina, 
                                                   matriz_disciplina_ch_ano, disciplina_id, disciplina_nome, disciplina_cor_fundo, disciplina_eixo_id, disciplina_eixo_nome
                                            FROM smc_matriz_disciplinas
                                            INNER JOIN smc_disciplina ON disciplina_id = matriz_disciplina_id_disciplina
                                            LEFT JOIN smc_disciplina_eixos ON matriz_disciplina_eixo = disciplina_eixo_id
                                            WHERE matriz_disciplina_id_matriz = :matriz_id AND disciplina_id = :disciplina_id";
                                        $stmt_MatrizDisciplinas = $SmecelNovo->prepare($query_MatrizDisciplinas);
                                        $stmt_MatrizDisciplinas->execute([
                                            ':matriz_id' => $row_Turmas['turma_matriz_id'],
                                            ':disciplina_id' => $row_Turmas['disciplina_id']
                                        ]);
                                        $MatrizDisciplinas = $stmt_MatrizDisciplinas->fetchAll(PDO::FETCH_ASSOC);
                                        $row_MatrizDisciplinas = reset($MatrizDisciplinas);
                                        $totalRows_MatrizDisciplinas = count($MatrizDisciplinas);

                                        $disciplinaNome = $row_Turmas['disciplina_nome'];
                                        if ($totalRows_MatrizDisciplinas != 0 && $row_MatrizDisciplinas['disciplina_eixo_nome']) {
                                            $disciplinaNome .= " - ({$row_MatrizDisciplinas['disciplina_eixo_nome']})";
                                        }
                                        ?>
                                        <a <?php if ($row_Turmas['turma_turno'] == "1") { ?>style="background-color:#006699;"
                                            <?php } else if ($row_Turmas['turma_turno'] == "3") { ?>style="background-color:#006633" <?php } ?>
                                            class="ls-btn-primary ls-btn ls-xs-margin-bottom ls-xs-margin-right"
                                            href="<?php echo $link_target; ?>?escola=<?php echo $row_escola['escola_id']; ?>&turma=<?php echo $row_Turmas[$tabela_turma]; ?>&target=<?php echo $target; ?>&data=<?php echo $data; ?>&nova">
                                            <?php if ($aulaNum == 1) {
                                                echo $row_Turmas['ch_lotacao_aula'];
                                            } ?>
                                            <?php //echo $disciplinaNome; ?>
                                            <?php //echo $row_Turmas['turma_nome']; ?>
                                            <?php //echo $row_Turmas['turma_turno_nome']; ?>
                                        </a>
                                    <?php } ?>
                                </div>
                            <?php } else { ?>
                                <li><a href="#">Nenhuma turma vinculada nesta data</a></li>
                            <?php } ?>
                        </label>
                    </div>
                </form>
            </div>
        </div>
    </main>
    <?php include_once "inc/notificacoes.php"; ?>
    <script type="text/javascript" src="https://code.jquery.com/jquery-2.1.4.min.js"></script>
    <script src="js/locastyle.js"></script>
    <script src="//cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="js/sweetalert2.min.js"></script>
    <script type="application/javascript">
        /*
        Swal.fire({
            //position: 'top-end',
            icon: 'success',
            title: 'Tudo certo por aqui',
            showConfirmButton: false,
            timer: 1500
        })
        */
    </script>
</body>

</html>