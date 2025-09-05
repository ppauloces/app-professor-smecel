<?php


if(isset($_POST["matricula"])) {
	
require_once('../../../../Connections/SmecelNovo.php');

extract($_POST);

	  mysql_select_db($database_SmecelNovo, $SmecelNovo);
	  $query_Verifica = "
	  SELECT faltas_alunos_id, faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data 
	  FROM smc_faltas_alunos 
	  WHERE faltas_alunos_matricula_id = '$matricula' AND faltas_alunos_data = '$data' AND faltas_alunos_numero_aula = '$aula_numero'";
	  $Verifica = mysql_query($query_Verifica, $SmecelNovo) or die(mysql_error());
	  $row_Verifica = mysql_fetch_assoc($Verifica);
	  $totalRows_Verifica = mysql_num_rows($Verifica);


if (empty($matricula)) {
			echo "<script>M.toast({html: '<i class=\"material-icons red-text\">block</i>&nbsp;<button class=\"btn-flat toast-action\"> Informe o código $totalRows_Verifica </button>'});</script>";
			exit;

} elseif ($totalRows_Verifica > 0) {
	
	
			  $deleteSQL = sprintf("DELETE FROM smc_faltas_alunos WHERE faltas_alunos_id = '$row_Verifica[faltas_alunos_id]'");
			  mysql_select_db($database_SmecelNovo, $SmecelNovo);
			  $Result2 = mysql_query($deleteSQL, $SmecelNovo) or die(mysql_error());

			/*
			  echo "<script>M.toast({html: '<i class=\"material-icons\">check_circle</i>&nbsp;<button class=\"btn-flat toast-action\">Falta excluída com sucesso.</button>'});</script>";
			*/
			
			echo "<script>Swal.fire({ position: 'top-end', icon: 'success', title: 'Presença Lançada',  text: '$aluno', showConfirmButton: false, timer: 1000 })</script>";

			
			exit;

} else {
			
			
			  $insertSQL = sprintf("INSERT INTO smc_faltas_alunos (faltas_alunos_matricula_id, faltas_alunos_disciplina_id, faltas_alunos_numero_aula, faltas_alunos_data) VALUES ('$matricula', '$disciplina', '$aula_numero', '$data')");
			  mysql_select_db($database_SmecelNovo, $SmecelNovo);
			  $Result1 = mysql_query($insertSQL, $SmecelNovo) or die(mysql_error());
			  
			  /*
			  echo "<script>M.toast({html: '<i class=\"material-icons\">check_circle</i>&nbsp;<button class=\"btn-flat toast-action\">Falta realizada com sucesso. </button>'});</script>";
			  */
              //echo "LANCADO";
			  
			  echo "<script>Swal.fire({ position: 'top-end', icon: 'success', title: 'Falta lançada', text: '$aluno', showConfirmButton: false, timer: 1000 })</script>";
			  
              
			  exit;
			
			
/*
if ($vazio == 1) {

	mysql_select_db($database_SmecelNovo, $SmecelNovo);
	$updateSQL = "
	UPDATE smc_nota SET nota_valor = '$valor' WHERE nota_hash = '$id' 
	";
	$Result1 = mysql_query($updateSQL, $SmecelNovo) or die(mysql_error());

} else {

	mysql_select_db($database_SmecelNovo, $SmecelNovo);
	$updateSQL = "
	UPDATE smc_nota SET nota_valor = NULL WHERE nota_hash = '$id' 
	";
	$Result1 = mysql_query($updateSQL, $SmecelNovo) or die(mysql_error());
	
}


    // Se inserido com sucesso
    if ($Result1) {
    
	echo "<script>M.toast({html: '<i class=\"material-icons green\">check_circle</i>&nbsp;<button class=\"btn-flat toast-action\">Nota <strong>$valor</strong> da disciplina <strong>$disciplina</strong> salva com sucesso. Nota anterior: <strong>$notaAnterior</strong></button>'});</script>";
	
	} 
    // Se houver algum erro ao inserir
    else {
		die("<div class=\"card-panel red lighten-4\">Não foi possível inserir as informações. Tente novamente.</div>" . mysql_error());
    }
	
*/


}
} else {
	
	echo "Como é que você veio parar aqui?<br>";
	
	function get_client_ip() {
    $ipaddress = '';
    if (isset($_SERVER['HTTP_CLIENT_IP']))
        $ipaddress = $_SERVER['HTTP_CLIENT_IP'];
    else if(isset($_SERVER['HTTP_X_FORWARDED_FOR']))
        $ipaddress = $_SERVER['HTTP_X_FORWARDED_FOR'];
    else if(isset($_SERVER['HTTP_X_FORWARDED']))
        $ipaddress = $_SERVER['HTTP_X_FORWARDED'];
    else if(isset($_SERVER['HTTP_FORWARDED_FOR']))
        $ipaddress = $_SERVER['HTTP_FORWARDED_FOR'];
    else if(isset($_SERVER['HTTP_FORWARDED']))
        $ipaddress = $_SERVER['HTTP_FORWARDED'];
    else if(isset($_SERVER['REMOTE_ADDR']))
        $ipaddress = $_SERVER['REMOTE_ADDR'];
    else
        $ipaddress = 'UNKNOWN';
    return $ipaddress;

	
} echo get_client_ip();

header("Location:../../index.php?err");
	
	}
?>