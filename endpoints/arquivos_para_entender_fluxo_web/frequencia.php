<?php require_once('../../Connections/SmecelNovoPDO.php'); ?>
<?php include "conf/session.php"; ?>
<?php include "fnc/anti_injection.php"; ?>

<?php
$colname_Escola = "-1";
if (isset($_GET['escola'])) {
    $colname_Escola = anti_injection($_GET['escola']);
} else {
    //header("Location:chamada.php");
}

$colname_Target = "-1";
if (isset($_GET['target'])) {
    $colname_Target = anti_injection($_GET['target']);
} else {
    //header("Location:chamada.php");
}

$colname_Turma = "-1";
if (isset($_GET['turma'])) {
    $colname_Turma = anti_injection($_GET['turma']);
} else {
    //header("Location:chamada.php");
}

// Validação de acesso à escola e turma
$query_validate_access = "
    SELECT 
        e.escola_id,
        (SELECT COUNT(*) 
         FROM smc_vinculo v 
         WHERE v.vinculo_id_escola = e.escola_id 
         AND v.vinculo_id_funcionario = :professor_id 
         AND v.vinculo_status = '1') AS has_vinculo,
        (SELECT COUNT(*) 
         FROM smc_ch_lotacao_professor l 
         WHERE l.ch_lotacao_escola = e.escola_id 
         AND l.ch_lotacao_professor_id = :professor_id) AS has_lotacao,
        (SELECT COUNT(*) 
         FROM smc_ch_lotacao_professor l 
         WHERE l.ch_lotacao_id = :aula_id 
         AND l.ch_lotacao_professor_id = :professor_id) AS is_aula_professor
    FROM smc_escola e
    WHERE e.escola_id = :escola_id";

$stmt_validate = $SmecelNovo->prepare($query_validate_access);
$stmt_validate->execute([
    ':professor_id' => $row_ProfLogado['func_id'],
    ':escola_id' => $colname_Escola,
    ':aula_id' => $colname_Turma
]);
$validation_result = $stmt_validate->fetch(PDO::FETCH_ASSOC);

// Redireciona se não tiver permissão
if (
    !$validation_result ||
    $validation_result['has_vinculo'] == 0 ||
    $validation_result['has_lotacao'] == 0 ||
    $validation_result['is_aula_professor'] == 0
) {
    header("Location: index.php?permissao");
    exit;
}

$colname_Aula = "-1";
if (isset($_GET['turma'])) {
    $colname_Aula = anti_injection($_GET['turma']);
} else {
    //header("Location:chamada.php");
}

if (isset($_GET['data'])) {
    $data = anti_injection($_GET['data']);
    $semana = date("w", strtotime($data));
    $diasemana = array('DOMINGO', 'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA', 'SÁBADO');
    $dia_semana_nome = $diasemana[$semana];
    $ano = date("Y", strtotime($data));
} else {
    //header("Location:chamada.php");
}

$todas = "s";
if (isset($_GET['todas'])) {
    $todas = anti_injection($_GET['todas']);
} else {
    $todas = "s";
}

// Query para Aula
$query_Aula = "
    SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, 
    ch_lotacao_turma_id, ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, 
    disciplina_id, disciplina_nome, turma_id, turma_nome, turma_turno,
    CASE turma_turno
    WHEN 0 THEN 'INTEGRAL'
    WHEN 1 THEN 'MATUTINO'
    WHEN 2 THEN 'VESPERTINO'
    WHEN 3 THEN 'NOTURNO'
    END AS turma_turno_nome
    FROM smc_ch_lotacao_professor
    INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
    INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
    WHERE ch_lotacao_id = :aula_id";
$stmt_Aula = $SmecelNovo->prepare($query_Aula);
$stmt_Aula->bindParam(':aula_id', $colname_Aula, PDO::PARAM_INT);
$stmt_Aula->execute();
$Aula = $stmt_Aula->fetchAll(PDO::FETCH_ASSOC);
$row_Aula = reset($Aula);
$totalRows_Aula = count($Aula);

if ($totalRows_Aula == 0) {
    //header("Location:chamada.php");
}

// Query para Turma
$query_Turma = "
    SELECT turma_id, turma_id_escola, turma_id_sec, turma_matriz_id, turma_nome, turma_etapa, 
           turma_turno, turma_total_alunos, turma_ano_letivo, turma_parecer 
    FROM smc_turma 
    WHERE turma_id = :turma_id";
$stmt_Turma = $SmecelNovo->prepare($query_Turma);
$stmt_Turma->bindParam(':turma_id', $row_Aula['ch_lotacao_turma_id'], PDO::PARAM_INT);
$stmt_Turma->execute();
$Turma = $stmt_Turma->fetchAll(PDO::FETCH_ASSOC);
$row_Turma = reset($Turma);
$totalRows_Turma = count($Turma);

// Query para Vínculos
$query_Vinculos = "
    SELECT vinculo_id, vinculo_id_escola, vinculo_id_sec, vinculo_id_funcionario 
    FROM smc_vinculo 
    WHERE vinculo_id_escola = :escola_id AND vinculo_id_funcionario = :func_id";
$stmt_Vinculos = $SmecelNovo->prepare($query_Vinculos);
$stmt_Vinculos->execute([
    ':escola_id' => $row_Turma['turma_id_escola'],
    ':func_id' => $row_ProfLogado['func_id']
]);
$Vinculos = $stmt_Vinculos->fetchAll(PDO::FETCH_ASSOC);
$row_Vinculos = reset($Vinculos);
$totalRows_Vinculos = count($Vinculos);

if(isset($_GET['ano'])) {
    $ano_letivo = anti_injection($_GET['ano']);
} elseif (!empty($ano)) {
    $ano_letivo = $ano;
} else {
    $ano_letivo = $row_AnoLetivo['ano_letivo_ano'];
}


// Query para Outras aulas
$query_Outras = "
    SELECT ch_lotacao_id, ch_lotacao_professor_id, ch_lotacao_disciplina_id, ch_lotacao_turma_id, 
           ch_lotacao_dia, ch_lotacao_aula, ch_lotacao_obs, ch_lotacao_escola, disciplina_id, 
           disciplina_nome, disciplina_nome_abrev, turma_id, turma_ano_letivo, turma_turno
    FROM smc_ch_lotacao_professor
    INNER JOIN smc_disciplina ON disciplina_id = ch_lotacao_disciplina_id
    INNER JOIN smc_turma ON turma_id = ch_lotacao_turma_id
    WHERE turma_ano_letivo = :ano_letivo 
    AND ch_lotacao_dia = :dia 
    AND ch_lotacao_professor_id = :professor_id
    ORDER BY turma_turno, ch_lotacao_aula ASC";
$stmt_Outras = $SmecelNovo->prepare($query_Outras);
$stmt_Outras->execute([
    ':ano_letivo' => $ano_letivo,
    ':dia' => $row_Aula['ch_lotacao_dia'],
    ':professor_id' => $row_Vinculos['vinculo_id_funcionario']
]);
$Outras = $stmt_Outras->fetchAll(PDO::FETCH_ASSOC);
$row_Outras = reset($Outras);
$totalRows_Outras = count($Outras);

$aulasGrupo = [];
foreach ($Outras as $outra) {
    if (
        $outra['ch_lotacao_turma_id'] == $row_Aula['ch_lotacao_turma_id']
        && $outra['ch_lotacao_disciplina_id'] == $row_Aula['ch_lotacao_disciplina_id']
    ) {
        $aulasGrupo[] = [
            'ch_lotacao_id' => $outra['ch_lotacao_id'],
            'ch_lotacao_aula' => $outra['ch_lotacao_aula']
        ];
    }
}


$colname_Alunos = "-1";
if (isset($_GET['turma'])) {
    $colname_Alunos = anti_injection($_GET['turma']);
}

// Query para Alunos
$query_Alunos = "
    SELECT vinculo_aluno_id, vinculo_aluno_id_aluno, vinculo_aluno_id_turma, vinculo_aluno_id_escola, 
           vinculo_aluno_id_sec, vinculo_aluno_ano_letivo, vinculo_aluno_transporte, vinculo_aluno_ponto_id, 
           vinculo_aluno_data, vinculo_aluno_hash, vinculo_aluno_verificacao, vinculo_aluno_boletim, 
           vinculo_aluno_situacao, vinculo_aluno_datatransferencia, vinculo_aluno_da_casa, 
           vinculo_aluno_historico_transferencia, vinculo_aluno_vacina_atualizada, vinculo_aluno_vacina_data_retorno, 
           vinculo_aluno_conselho, vinculo_aluno_conselho_parecer, vinculo_aluno_dependencia, 
           aluno_id, aluno_nome, aluno_nascimento, aluno_foto, aluno_aluno_com_deficiencia, aluno_tipo_deficiencia,
           CASE vinculo_aluno_situacao
           WHEN 1 THEN 'MATRICULADO'
           WHEN 2 THEN 'TRANSFERIDO(A)'
           WHEN 3 THEN 'DESISTENTE'
           WHEN 4 THEN 'FALECIDO(A)'
           WHEN 5 THEN 'OUTROS'
           END AS vinculo_aluno_situacao_nome 
    FROM smc_vinculo_aluno
    INNER JOIN smc_aluno ON aluno_id = vinculo_aluno_id_aluno
    WHERE vinculo_aluno_id_turma = :turma_id
    ORDER BY aluno_nome ASC";
$stmt_Alunos = $SmecelNovo->prepare($query_Alunos);
$stmt_Alunos->bindParam(':turma_id', $row_Turma['turma_id'], PDO::PARAM_INT);
$stmt_Alunos->execute();
$Alunos = $stmt_Alunos->fetchAll(PDO::FETCH_ASSOC);
$row_Alunos = reset($Alunos);
$totalRows_Alunos = count($Alunos);

// Verificar permissão da secretaria para professor justificar faltas
$query_Secretaria = "
    SELECT sec_prof_justifica_falta 
    FROM smc_sec 
    WHERE sec_id = :sec_id";
$stmt_Secretaria = $SmecelNovo->prepare($query_Secretaria);
$stmt_Secretaria->execute([':sec_id' => $row_Turma['turma_id_sec']]);
$Secretaria = $stmt_Secretaria->fetch(PDO::FETCH_ASSOC);
$professor_pode_justificar = ($Secretaria && $Secretaria['sec_prof_justifica_falta'] == 'S');
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
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/driver.js@latest/dist/driver.css" />
    <link rel="stylesheet" type="text/css" href="css/locastyle.css">
    <link rel="stylesheet" href="css/sweetalert2.min.css">
    <style>
        img.aluno {
            background-color: #ddd;
            /* Cor de fundo para áreas não cobertas */
            border-radius: 50% !important;
            /* Círculo perfeito */
            width: 40px !important;
            /* Largura fixa de 40px */
            height: 40px !important;
            /* Altura fixa de 40px */
            object-fit: cover;
            /* Preenche o contêiner, recortando o excesso */
            display: block;
            /* Trata como bloco */
            box-sizing: border-box;
            /* Evita que padding/bordas afetem o tamanho */
            margin: 0 auto;
            /* Centraliza a imagem na célula */
        }

        /* Ajustar a célula da tabela para acomodar a imagem */
        table.ls-table td:nth-child(1) {
            width: 50px;
            /* Espaço suficiente para a imagem */
            min-width: 50px;
            /* Garante que a célula não encolha */
            height: 50px;
            /* Altura fixa para alinhamento */
            text-align: center;
            /* Centraliza a imagem */
            vertical-align: middle;
            /* Alinha verticalmente */
            padding: 5px;
            /* Padding reduzido para imagens menores */
        }

        table.ls-table {
            width: 100%;
            table-layout: fixed;
            /* Força larguras definidas */
        }

        table.ls-table th,
        table.ls-table td {
            padding: 5px;
            /* Ajustado para imagens menores */
            word-wrap: break-word;
        }

        table.ls-table th:nth-child(1),
        table.ls-table td:nth-child(1) {
            width: 10%;
        }

        table.ls-table th:nth-child(2),
        table.ls-table td:nth-child(2) {
            width: 60%;
        }

        table.ls-table th:nth-child(3),
        table.ls-table td:nth-child(3) {
            width: 15%;
        }

        table.ls-table th:nth-child(4),
        table.ls-table td:nth-child(4) {
            width: 15%;
        }

        td small {
            display: block;
            white-space: normal;
        }

        img.pne-icon {
            width: 15px;
            vertical-align: middle;
            margin-left: 5px;
            cursor: pointer;
        }

        /* Ajustes responsivos para telas menores */
        @media (max-width: 600px) {

            table.ls-table th:nth-child(1),
            table.ls-table td:nth-child(1) {
                width: 15%;
                /* Aumenta ligeiramente a largura da coluna em telas pequenas */
                min-width: 45px;
                /* Garante espaço para a imagem */
            }

            table.ls-table th:nth-child(2),
            table.ls-table td:nth-child(2) {
                width: 55%;
                /* Ajusta a proporção */
            }

            table.ls-table th:nth-child(3),
            table.ls-table td:nth-child(3) {
                width: 15%;
            }

            table.ls-table th:nth-child(4),
            table.ls-table td:nth-child(4) {
                width: 15%;
            }

            img.aluno {
                width: 36px !important;
                /* Reduz ligeiramente em telas muito pequenas */
                height: 36px !important;
            }

            table.ls-table td:nth-child(1) {
                width: 45px;
                min-width: 45px;
                height: 45px;
                padding: 3px;
            }
        }
    </style>
</head>

<body>
    <?php include_once "inc/navebar.php"; ?>
    <?php include_once "inc/sidebar.php"; ?>
    <main class="ls-main">
        <div class="container-fluid">
            <h1 class="ls-title-intro ls-ico-home">FREQUÊNCIA</h1>




            <div data-ls-module="dropdown" class="ls-dropdown ls-float-right">
                <a href="#" class="ls-btn ls-ico-cog ls-float-right"> </a>
                <ul class="ls-dropdown-nav">
                    <li><a href="#" data-ls-module="modal" data-target="#configuracoes">Forma de registro de faltas</a>
                    </li>
                    <li><a href="#" data-ls-module="modal" data-target="#mudaData" class="ls-divider">Alterar data</a>
                    </li>
                    <li><a href="mapa_faltas.php?escola=<?php echo $colname_Escola; ?>&turma=<?php echo $colname_Turma; ?>&target=frequencia&data=<?php echo $data; ?>&todas=s&ct=<?php echo $row_Turma['turma_id']; ?>"
                            class="ls-divider">Frequência da turma</a></li>
                </ul>
            </div>

            <a href="selecionar.php?escola=<?php echo $colname_Escola; ?>&target=frequencia&data=<?php echo $data; ?>"
                class="ls-btn ls-ico-chevron-left">Voltar</a>






            <div class="ls-box-filter">
                <h5 class="ls-title-5"><?php echo $row_Turma['turma_nome']; ?> -
                    <?php echo $row_Aula['turma_turno_nome']; ?>
                </h5>
                <p><strong><?php echo $row_Aula['disciplina_nome']; ?> - <?php echo date("d/m/y", strtotime($data)); ?>
                        (<?php echo $dia_semana_nome; ?>)</strong></p>

                <small>
                    <div class="ls-float-right">

                        <?php if ($todas == "s") {
                            echo "*as faltas serão registradas em todas as aulas";
                        } ?>

                        <?php if ($todas == "n") {
                            echo "*a falta será registrada apenas na aula selecionada";
                        } ?>


                    </div>
                </small>

            </div>





            <div class="ls-pagination-filter">
                <ul class="ls-pagination ls-float-left">
                    <?php foreach ($Outras as $row_Outras) { ?>
                        <li
                            class="<?php if ($row_Outras['ch_lotacao_id'] == $row_Aula['ch_lotacao_id']) { ?>ls-active<?php } ?> ls-xs-margin-bottom ls-xs-margin-right">
                            <a
                                href="frequencia.php?escola=<?php echo $colname_Escola; ?>&turma=<?php echo $row_Outras['ch_lotacao_id']; ?>&target=<?php echo $colname_Target; ?>&data=<?php echo $data; ?>&todas=<?php echo $todas; ?>">
                                <?php echo $row_Outras['ch_lotacao_aula']; ?>ª
                            </a>
                        </li>
                    <?php } ?>
                </ul>
            </div>








            <table class="ls-table">
                <thead>
                    <tr>
                        <th class="ls-txt-center"></th>
                        <th>ALUNOS</th>
                        <th class="ls-txt-center">PRESENÇA</th>
                        <?php if ($professor_pode_justificar) { ?>
                            <th class="ls-txt-center">AÇÕES</th>
                        <?php } ?>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    $num = 1;
                    foreach ($Alunos as $row_Alunos) {
                        $query_Verifica = "
                SELECT faltas_alunos_id, faltas_alunos_matricula_id, faltas_alunos_disciplina_id, 
                       faltas_alunos_numero_aula, faltas_alunos_justificada, faltas_alunos_data 
                FROM smc_faltas_alunos 
                WHERE faltas_alunos_matricula_id = :matricula_id 
                AND faltas_alunos_data = :data 
                AND faltas_alunos_numero_aula = :aula_numero";
                        $stmt_Verifica = $SmecelNovo->prepare($query_Verifica);
                        $stmt_Verifica->execute([
                            ':matricula_id' => $row_Alunos['vinculo_aluno_id'],
                            ':data' => $data,
                            ':aula_numero' => $row_Aula['ch_lotacao_aula']
                        ]);
                        $Verifica = $stmt_Verifica->fetchAll(PDO::FETCH_ASSOC);
                        $row_Verifica = reset($Verifica);
                        $totalRows_Verifica = count($Verifica);
                        ?>
                        <tr>
                            <td class="ls-txt-center"> <!-- Alterado de ls-txt-left para ls-txt-center -->
                                <?php if (empty($row_Alunos['aluno_foto'])) { ?>
                                    <img src="https://www.smecel.com.br/aluno/fotos/semfoto.jpg" class="aluno"
                                        alt="Foto do aluno">
                                <?php } else { ?>
                                    <img src="https://www.smecel.com.br/aluno/fotos/<?php echo htmlspecialchars($row_Alunos['aluno_foto'], ENT_QUOTES, 'UTF-8'); ?>"
                                        class="aluno" alt="Foto do aluno">
                                <?php } ?>
                            </td>
                            <td>
                                <small>
                                    <?php echo $row_Alunos['aluno_nome']; ?>
                                    <?php if ($row_Alunos['aluno_aluno_com_deficiencia'] == "1") { ?>
                                        <img src="../../img/pne.png" class="pne-icon" alt="Aluno(a) com necessidades especiais"
                                            title="Aluno(a) com necessidades especiais: <?php echo $row_Alunos['aluno_tipo_deficiencia']; ?>">
                                    <?php } ?>
                                    <?php if ($row_Alunos['vinculo_aluno_situacao'] != "1") { ?>
                                        <br><span
                                            class="ls-color-danger"><?php echo $row_Alunos['vinculo_aluno_situacao_nome']; ?></span>
                                    <?php } ?>
                                    <?php if ($row_Verifica['faltas_alunos_justificada'] == "S") { ?>
                                        <br><span class="ls-color-info">JUSTIFICADA</span>
                                    <?php } ?>
                                    <?php if ($row_Alunos['vinculo_aluno_dependencia'] == "S") { ?>
                                        <br><span class="ls-color-danger">CUMPRINDO DEPENDÊNCIA NA TURMA</span>
                                    <?php } ?>
                                </small>
                                <a href="mapa_faltas_individual.php?escola=<?php echo $colname_Escola; ?>&turma=<?php echo $colname_Turma; ?>&target=frequencia&data=<?php echo $data; ?>&todas=s&ct=<?php echo $row_Turma['turma_id']; ?>&aluno=<?php echo $row_Alunos['vinculo_aluno_id']; ?>"
                                    class="ls-ico-eye ls-ico-right"></a>
                            </td>
                            <td class="center card-panel1">
                                <div data-ls-module="switchButton" class="ls-switch-btn ls-float-right">
                                    <input type="checkbox" id="<?php echo $row_Alunos['vinculo_aluno_id']; ?>"
                                        class="js-frequencia-checkbox" dia="<?php echo $row_Aula['ch_lotacao_dia']; ?>"
                                        turma="<?php echo $row_Alunos['vinculo_aluno_id_turma']; ?>"
                                        ano="<?php echo $row_AnoLetivo['ano_letivo_ano']; ?>"
                                        prof="<?php echo $row_ProfLogado['func_id']; ?>"
                                        aluno="<?php echo $row_Alunos['aluno_nome']; ?>" data="<?php echo $data; ?>"
                                        matricula="<?php echo $row_Alunos['vinculo_aluno_id']; ?>"
                                        disciplina="<?php echo $row_Aula['disciplina_id']; ?>"
                                        aula_numero="<?php echo $row_Aula['ch_lotacao_aula']; ?>"
                                        multi="<?php echo $todas; ?>"
                                        data-tem-falta="<?php echo $totalRows_Verifica > 0 ? 1 : 0; ?>" <?php if ($row_Alunos['vinculo_aluno_situacao'] != "1" || $row_Verifica['faltas_alunos_justificada'] == "S") { ?> disabled <?php } else { ?>
                                            <?php if ($totalRows_Verifica == 0) {
                                                echo "checked";
                                            } ?>     <?php } ?>>
                                    <label class="ls-switch-label" for="<?php echo $row_Alunos['vinculo_aluno_id']; ?>"
                                        name="label-<?php echo $row_Alunos['vinculo_aluno_id']; ?>"
                                        ls-switch-off="<?php if ($row_Verifica['faltas_alunos_justificada'] == "S") { ?>Justificada<?php } else if ($row_Alunos['vinculo_aluno_situacao'] != "1") { ?>Transf.<?php } else { ?>Ausente<?php } ?>"
                                        ls-switch-on="Presente"><span></span></label>
                                </div>
                            </td>
                            <?php if ($professor_pode_justificar) { ?>
                                <td class="ls-txt-center">
                                    <?php if ($totalRows_Verifica > 0 && $row_Verifica['faltas_alunos_justificada'] != "S") { ?>
                                        <button class="ls-btn ls-btn-xs ls-btn-primary"
                                            onclick="justificarFalta('<?php echo $row_Alunos['vinculo_aluno_id']; ?>', '<?php echo $row_Alunos['aluno_nome']; ?>', '<?php echo $row_Aula['ch_lotacao_aula']; ?>', '<?php echo $row_Aula['disciplina_nome']; ?>', '<?php echo $data; ?>')">
                                            Justificar
                                        </button>
                                    <?php } elseif ($row_Verifica['faltas_alunos_justificada'] == "S") { ?>
                                        <span class="ls-tag-success">Justificada</span>
                                    <?php } else { ?>
                                        <span class="ls-tag">Presente</span>
                                    <?php } ?>
                                </td>
                            <?php } ?>
                        </tr>
                    <?php } ?>
                </tbody>
            </table>
            <div class="ls-box" id="confirmarFrequenciaLabel">
                <h5 class="ls-title-5">Confirmar chamada</h5>
                <?php if (count($aulasGrupo) >= 1) { ?>
                    <p class="ls-text-sm">Selecione as aulas que deseja confirmar com esta mesma chamada:</p>
                    <div style="display: flex; flex-wrap: wrap; gap: 15px; align-items: center;">
                        <?php foreach ($aulasGrupo as $aulaGrupo) { ?>
                            <?php
                            $checked = ($todas == "s" || $aulaGrupo['ch_lotacao_id'] == $row_Aula['ch_lotacao_id']) ? 'checked' : '';
                            ?>
                            <label style="font-size: 0.85em; margin: 0; display: inline-flex; align-items: center; gap: 5px;">
                                <input type="checkbox" class="js-aulas-confirmar"
                                    value="<?php echo $aulaGrupo['ch_lotacao_aula']; ?>" <?php echo $checked; ?>>
                                <span style="font-size: 0.9em;"><?php echo $aulaGrupo['ch_lotacao_aula']; ?>ª</span>
                            </label>
                        <?php } ?>
                    </div>
                <?php } else { ?>
                    <input type="hidden" class="js-aulas-confirmar" value="<?php echo $row_Aula['ch_lotacao_aula']; ?>"
                        checked>
                <?php } ?>
                <p id="frequencia-pendencias" class="ls-text-sm ls-color-info"></p>
                <button type="button" id="btn-confirmar-frequencia" class="ls-btn-primary" disabled>Confirmar
                    chamada</button>
            </div>
            <div id="status"></div>
            <hr>
        </div>
    </main>
    <?php include_once "inc/notificacoes.php"; ?>

    <div class="ls-modal" id="mudaData">
        <div class="ls-modal-box">
            <div class="ls-modal-header">
                <button data-dismiss="modal">×</button>
                <h4 class="ls-modal-title">SELECIONAR SÁBADO</h4>
            </div>
            <div class="ls-modal-body" id="myModalBody">
                <p class="ls-text-sm ls-color-info">
                    Esta função permite alterar a data apenas para um sábado. Não utilize para lançar frequência
                    retroativa de outros dias.
                </p>
                <form action="frequencia.php" class="ls-form" id="formData">
                    <input type="hidden" name="escola" value="<?php echo $colname_Escola; ?>">
                    <input type="hidden" name="turma" value="<?php echo $colname_Turma; ?>">
                    <input type="hidden" name="target" value="<?php echo $colname_Target; ?>">
                    <label class="ls-label col-md-12 col-xs-12">
                        <b class="ls-label-text">DATA (Apenas Sábados)</b>
                        <input type="date" name="data" class="" id="data" value="<?php echo $data; ?>"
                            autocomplete="off">
                    </label>
                    <input type="hidden" name="alterada" value="true">
                </form>
            </div>
            <div class="ls-modal-footer">
                <button type="button" class="ls-btn ls-btn-primary ls-btn-block"
                    onclick="validarSabado()">CONFIRMAR</button>
                <button type="button" class="ls-btn ls-btn-secondary ls-btn-block" data-dismiss="modal">FECHAR</button>
            </div>
        </div>
    </div>

    <div class="ls-modal" id="configuracoes">
        <div class="ls-modal-box">
            <div class="ls-modal-header">
                <button data-dismiss="modal">&times;</button>
                <h4 class="ls-modal-title">CONFIGURAÇÕES</h4>
            </div>
            <div class="ls-modal-body" id="myModalBody">
                <p>
                    Escolha como será feito o registro das faltas nas aulas:


                <div class="ls-group-btn ls-group-active">

                    <a href="frequencia.php?escola=<?php echo $colname_Escola; ?>&turma=<?php echo $colname_Turma; ?>&target=<?php echo $colname_Target; ?>&data=<?php echo $data; ?>&todas=s#configuracoes"
                        class="ls-btn <?php if ($todas == "s") {
                            echo "ls-active ls-ico-checkmark-circle ls-color-success";
                        } ?>">Em todas</a>

                    <a href="frequencia.php?escola=<?php echo $colname_Escola; ?>&turma=<?php echo $colname_Turma; ?>&target=<?php echo $colname_Target; ?>&data=<?php echo $data; ?>&todas=n#configuracoes"
                        class="ls-btn <?php if ($todas == "n") {
                            echo "ls-active ls-ico-checkmark-circle ls-color-success";
                        } ?>">Apenas
                        a selecionada</a>
                </div>
                <small>*a exclusão da falta é individual</small>
                </p>



            </div>
            <div class="ls-modal-footer">
                <!--<button class="ls-btn ls-float-right" data-dismiss="modal">FECHAR</button>-->
                <button type="submit" class="ls-btn-primary" style="display:block" data-dismiss="modal">FECHAR</button>
            </div>
        </div>
    </div><!-- /.modal -->

    <!-- Modal para justificar falta -->
    <div class="ls-modal" id="justificarFaltaModal">
        <div class="ls-modal-box">
            <div class="ls-modal-header">
                <button data-dismiss="modal">&times;</button>
                <h4 class="ls-modal-title">JUSTIFICAR FALTA</h4>
            </div>
            <div class="ls-modal-body" id="myModalBody">
                <div class="ls-alert-info">
                    <strong>Justificar falta do aluno:</strong> <span id="alunoNome"></span><br>
                    <strong>Aula:</strong> <span id="aulaNumero"></span>ª - <span id="disciplinaNome"></span><br>
                    <strong>Data:</strong> <span id="dataFalta"></span>
                </div>

                <form method="post" class="ls-form row" id="formJustificar">
                    <label class="ls-label col-md-12">
                        <b class="ls-label-text">Texto da justificativa</b>
                        <input type="text" name="justificativa" id="justificativa" class="ls-field" required>
                    </label>

                    <label class="ls-label col-md-12">
                        <input type="checkbox" name="justificar_todas" id="justificar_todas" checked>
                        Justificar todas as faltas do dia <span id="dataFaltaCheckbox"></span>
                    </label>

                    <input type="hidden" name="matricula_id" id="matricula_id">
                    <input type="hidden" name="data" id="dataHidden">
                    <input type="hidden" name="aula_numero" id="aula_numero_hidden">
                    <input type="hidden" name="disciplina_id" value="<?php echo $row_Aula['disciplina_id']; ?>">
                    <input type="hidden" name="professor_id" value="<?php echo $row_ProfLogado['func_id']; ?>">
                </form>
            </div>
            <div class="ls-modal-footer">
                <button type="button" class="ls-btn-primary" onclick="enviarJustificativa()">JUSTIFICAR</button>
                <button type="button" class="ls-btn" data-dismiss="modal">CANCELAR</button>
            </div>
        </div>
    </div>

    <script type="text/javascript" src="https://code.jquery.com/jquery-2.1.4.min.js"></script>
    <script src="js/locastyle.js"></script>
    <script src="//cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <script src="https://cdn.jsdelivr.net/npm/driver.js@latest/dist/driver.js.iife.js"></script>
    <script src="js/sweetalert2.min.js"></script>
	<script src="js/driver.js"></script>

    <script type="text/javascript">
        function validarSabado() {
            var dataSelecionada = document.getElementById('data').value;
            var diaSemana = new Date(dataSelecionada).getDay(); // 0 = Domingo, 6 = Sábado

            // alert(diaSemana);
            if (diaSemana !== 5) {
                Swal.fire({
                    icon: 'error',
                    title: 'Data Inválida',
                    text: 'Por favor, selecione um sábado.',
                    showConfirmButton: true
                });
            } else {
                Swal.fire({
                    icon: 'success',
                    title: 'Data Confirmada',
                    text: 'Sábado selecionado com sucesso!',
                    timer: 1500,
                    showConfirmButton: false
                }).then(() => {
                    document.getElementById('formData').submit(); // Envia o formulário
                });
            }
        }

        function justificarFalta(matriculaId, alunoNome, aulaNumero, disciplinaNome, data) {
            console.log(matriculaId, alunoNome, aulaNumero, disciplinaNome, data);
            // Preencher os campos do modal
            document.getElementById('alunoNome').textContent = alunoNome;
            document.getElementById('aulaNumero').textContent = aulaNumero;
            document.getElementById('disciplinaNome').textContent = disciplinaNome;
            document.getElementById('dataFalta').textContent = formatarData(data);
            document.getElementById('dataFaltaCheckbox').textContent = formatarData(data);

            document.getElementById('matricula_id').value = matriculaId;
            document.getElementById('dataHidden').value = data;
            document.getElementById('aula_numero_hidden').value = aulaNumero;

            // Abrir o modal
            locastyle.modal.open("#justificarFaltaModal");
        }

        function formatarData(data) {
            // Dividir a data em partes para evitar problemas de fuso horário
            var partes = data.split('-');
            var ano = parseInt(partes[0]);
            var mes = parseInt(partes[1]) - 1; // Mês começa em 0 no JavaScript
            var dia = parseInt(partes[2]);

            var dataObj = new Date(ano, mes, dia);
            return dataObj.toLocaleDateString('pt-BR');
        }

        function enviarJustificativa() {
            var justificativa = document.getElementById('justificativa').value;
            if (!justificativa.trim()) {
                Swal.fire({
                    icon: 'error',
                    title: 'Campo obrigatório',
                    text: 'Por favor, preencha a justificativa.',
                    showConfirmButton: true
                });
                return;
            }

            // Mostrar loading
            Swal.fire({
                title: 'Processando...',
                text: 'Enviando justificativa',
                allowOutsideClick: false,
                didOpen: () => {
                    Swal.showLoading();
                }
            });

            // Enviar formulário via AJAX
            $.ajax({
                type: 'POST',
                url: 'justificar_falta.php',
                data: $('#formJustificar').serialize(),
                success: function (response) {
                    console.log('Resposta do servidor:', response);
                    try {
                        var result = JSON.parse(response);
                        if (result.status === 'success') {
                            Swal.fire({
                                icon: 'success',
                                title: 'Sucesso!',
                                text: result.message,
                                showConfirmButton: false,
                                timer: 2000
                            }).then(() => {
                                location.reload();
                            });
                        } else {
                            Swal.fire({
                                icon: 'error',
                                title: 'Erro!',
                                text: result.message,
                                showConfirmButton: true
                            });
                        }
                    } catch (e) {
                        console.error('Erro ao parsear JSON:', e);
                        console.log('Resposta bruta:', response);
                        Swal.fire({
                            icon: 'error',
                            title: 'Erro!',
                            text: 'Erro ao processar resposta do servidor: ' + response,
                            showConfirmButton: true
                        });
                    }
                },
                error: function (xhr, status, error) {
                    console.error('Erro AJAX:', xhr, status, error);
                    Swal.fire({
                        icon: 'error',
                        title: 'Erro!',
                        text: 'Erro ao enviar justificativa. Status: ' + status + ' - Erro: ' + error,
                        showConfirmButton: true
                    });
                }
            });
        }
    </script>
    <script type="text/javascript">
        $(document).ready(function () {
            var attendanceBuffer = {};
            var batchContext = {
                data: '<?php echo $data; ?>',
                disciplina: '<?php echo $row_Aula['disciplina_id']; ?>',
                turma: '<?php echo $row_Aula['ch_lotacao_turma_id']; ?>',
                prof: '<?php echo $row_ProfLogado['func_id']; ?>',
                ano: '<?php echo $row_AnoLetivo['ano_letivo_ano']; ?>'
            };

            function updatePendingUI() {
                var count = Object.keys(attendanceBuffer).length;
                if (count > 0) {
                    $("#frequencia-pendencias").text("Pendentes para salvar: " + count);
                    $("#btn-confirmar-frequencia").prop("disabled", false);
                } else {
                    $("#frequencia-pendencias").text("Nenhuma alteracao pendente.");
                    $("#btn-confirmar-frequencia").prop("disabled", true);
                }
            }

            function addAusencia(matricula) {
                attendanceBuffer[matricula] = true;
                updatePendingUI();
            }

            function removeAusencia(matricula) {
                if (attendanceBuffer[matricula]) {
                    delete attendanceBuffer[matricula];
                    updatePendingUI();
                }
            }

            function getSelectedAulas() {
                var aulas = [];
                $(".js-aulas-confirmar:checked").each(function () {
                    aulas.push($(this).val());
                });
                return aulas;
            }

            updatePendingUI();

            $(".js-frequencia-checkbox").on('change', function () {
                var $checkbox = $(this);
                var multi = $checkbox.attr('multi');
                var matricula = $checkbox.attr('matricula');
                var aula_numero = $checkbox.attr('aula_numero');
                var data = $checkbox.attr('data');
                var disciplina = $checkbox.attr('disciplina');
                var aluno = $checkbox.attr('aluno');
                var prof = $checkbox.attr('prof');
                var ano = $checkbox.attr('ano');
                var turma = $checkbox.attr('turma');
                var dia = $checkbox.attr('dia');
                var temFalta = $checkbox.attr('data-tem-falta') === "1";

                if ($checkbox.prop('checked')) {
                    removeAusencia(matricula);

                    if (!temFalta) {
                        return true;
                    }

                    $.ajax({
                        type: 'POST',
                        url: 'crud/alunos_frequencia/frequencia.php',
                        data: {
                            matricula: matricula,
                            aula_numero: aula_numero,
                            data: data,
                            aluno: aluno,
                            disciplina: disciplina,
                            multi: multi,
                            prof: prof,
                            ano: ano,
                            turma: turma,
                            dia: dia
                        },
                        success: function (data) {
                            $('#status').html(data);
                            $checkbox.attr('data-tem-falta', "0");
                            setTimeout(function () {
                                $("#status").html("");
                            }, 2000);
                        }
                    });
                    return true;
                }

                addAusencia(matricula);
                return true;
            });

            $("#btn-confirmar-frequencia").on('click', function () {
                var aulasSelecionadas = getSelectedAulas();
                var registros = Object.keys(attendanceBuffer).map(function (matricula) {
                    return { matricula: matricula, ausente: 1 };
                });

                if (aulasSelecionadas.length === 0) {
                    Swal.fire({
                        icon: 'error',
                        title: 'Selecione ao menos uma aula',
                        text: 'Escolha as aulas para confirmar a chamada.'
                    });
                    return;
                }

                if (registros.length === 0) {
                    Swal.fire({
                        icon: 'info',
                        title: 'Sem alteracoes pendentes',
                        text: 'Nao ha faltas novas para salvar.'
                    });
                    return;
                }

                Swal.fire({
                    title: 'Confirmar chamada',
                    text: 'Deseja salvar as faltas pendentes?',
                    showCancelButton: true,
                    confirmButtonText: 'Confirmar',
                    cancelButtonText: 'Cancelar'
                }).then(function (result) {
                    if (!result.isConfirmed) {
                        return;
                    }

                    $.ajax({
                        type: 'POST',
                        url: 'crud/alunos_frequencia/frequencia.php',
                        data: {
                            batch: 1,
                            data: batchContext.data,
                            disciplina: batchContext.disciplina,
                            turma: batchContext.turma,
                            prof: batchContext.prof,
                            ano: batchContext.ano,
                            aulas: aulasSelecionadas,
                            registros: registros
                        },
                        success: function (response) {
                            var resultData;
                            try {
                                resultData = JSON.parse(response);
                            } catch (e) {
                                resultData = { status: 'error', message: response };
                            }

                            if (resultData.status === 'ok') {
                                Swal.fire({
                                    icon: 'success',
                                    title: 'Chamada confirmada',
                                    text: 'Faltas salvas: ' + resultData.inseridos,
                                    timer: 2000,
                                    showConfirmButton: false
                                }).then(function () {
                                    //window.location.reload();
                                });
                            } else {
                                Swal.fire({
                                    icon: 'error',
                                    title: 'Erro ao salvar',
                                    text: resultData.message || 'Falha ao salvar faltas.'
                                });
                            }
                        },
                        error: function (xhr, status, error) {
                            Swal.fire({
                                icon: 'error',
                                title: 'Erro na requisicao',
                                text: 'Status: ' + status + ' - Erro: ' + error
                            });
                        }
                    });
                });
            });

            window.addEventListener('beforeunload', function (e) {
                if (Object.keys(attendanceBuffer).length > 0) {
                    e.preventDefault();
                    e.returnValue = '';
                }
            });
        });
    </script>
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
    <?php if (isset($_GET["alterada"])) { ?>
        <script type="application/javascript">
            Swal.fire({
                icon: 'success',
                title: 'DATA ALTERADA',
                text: '<?php echo $dia_semana_nome; ?> - <?php echo date("d/m/y", strtotime($data)); ?> ',
                showConfirmButton: false,
                timer: 2500
            })
        </script>
    <?php } ?>
</body>

</html>
