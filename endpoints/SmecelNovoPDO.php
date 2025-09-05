<?php
# FileName="Connection_php_pdo.php"
# Type="PDO"
# HTTP="true"

$hostname_SmecelNovo = "localhost";
$database_SmecelNovo = "smecel";
$username_SmecelNovo = "root";
$password_SmecelNovo = "";

try {
    $SmecelNovo = new PDO(
        "mysql:host=$hostname_SmecelNovo;dbname=$database_SmecelNovo",
        $username_SmecelNovo,
        $password_SmecelNovo,
        array(
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
        )
    );
} catch (PDOException $e) {
    die("<h3>Erro ao conectar ao banco de dados: " . htmlspecialchars($e->getMessage()) . "</h3>");
}
?>