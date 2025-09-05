<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

require_once('../../Connections/SmecelNovoPDO.php');

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $format = isset($_GET['format']) ? $_GET['format'] : 'csv';
    $module = isset($_GET['module']) ? $_GET['module'] : null;
    $queryJson = isset($_GET['query']) ? $_GET['query'] : null;
    
    if (!$module || !$queryJson) {
        http_response_code(400);
        echo "Parâmetros inválidos";
        exit;
    }
    
    try {
        $queryParams = json_decode($queryJson, true);
        
        if (!$queryParams) {
            throw new Exception("Query inválida");
        }
        
        // Carregar o dicionário
        $dictionaryPath = "../../sistema/secretaria/config/data_dictionary_{$module}.php";
        if (!file_exists($dictionaryPath)) {
            throw new Exception("Dicionário não encontrado");
        }
        
        $dictionary = require($dictionaryPath);
        
        // Executar query
        $queryBuilder = new QueryBuilder($dictionary, $SmecelNovo);
        $result = $queryBuilder->buildAndExecute([
            'fields' => $queryParams['selectedFields'],
            'filters' => $queryParams['filters'],
            'orderBy' => $queryParams['orderBy'],
            'limit' => 10000, // Limite para exportação
            'offset' => 0
        ]);
        
        if ($result['status'] !== 'success') {
            throw new Exception($result['message']);
        }
        
        $data = $result['data'];
        $fields = $queryParams['selectedFields'];
        
        if ($format === 'csv') {
            exportCSV($data, $fields, $dictionary);
        } elseif ($format === 'pdf') {
            exportPDF($data, $fields, $dictionary, $module);
        } else {
            throw new Exception("Formato não suportado");
        }
        
    } catch (Exception $e) {
        http_response_code(500);
        echo "Erro: " . $e->getMessage();
    }
} else {
    http_response_code(405);
    echo "Método não permitido";
}

function exportCSV($data, $fields, $dictionary) {
    $filename = "relatorio_alunos_" . date('Y-m-d_H-i-s') . ".csv";
    
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Cache-Control: must-revalidate, post-check=0, pre-check=0');
    header('Expires: 0');
    
    $output = fopen('php://output', 'w');
    
    // BOM para UTF-8
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));
    
    // Cabeçalhos
    $headers = [];
    foreach ($fields as $field) {
        $headers[] = getFieldLabel($field, $dictionary);
    }
    fputcsv($output, $headers, ';');
    
    // Dados
    foreach ($data as $row) {
        $rowData = [];
        foreach ($row as $value) {
            $rowData[] = $value;
        }
        fputcsv($output, $rowData, ';');
    }
    
    fclose($output);
}

function exportPDF($data, $fields, $dictionary, $module) {
    require_once('../../tcpdf/tcpdf.php');
    
    $pdf = new TCPDF(PDF_PAGE_ORIENTATION, PDF_UNIT, PDF_PAGE_FORMAT, true, 'UTF-8', false);
    
    // Configurações do PDF
    $pdf->SetCreator(PDF_CREATOR);
    $pdf->SetAuthor('SMECEL');
    $pdf->SetTitle('Relatório Personalizado - ' . ucfirst($module));
    $pdf->SetSubject('Relatório');
    $pdf->SetKeywords('SMECEL, Relatório, ' . ucfirst($module));
    
    $pdf->SetDefaultMonospacedFont(PDF_FONT_MONOSPACED);
    $pdf->SetMargins(PDF_MARGIN_LEFT, PDF_MARGIN_TOP, PDF_MARGIN_RIGHT);
    $pdf->SetHeaderMargin(PDF_MARGIN_HEADER);
    $pdf->SetFooterMargin(PDF_MARGIN_FOOTER);
    $pdf->SetAutoPageBreak(TRUE, PDF_MARGIN_BOTTOM);
    $pdf->setImageScale(PDF_IMAGE_SCALE_RATIO);
    
    $pdf->AddPage();
    
    // Título
    $pdf->SetFont('helvetica', 'B', 16);
    $pdf->Cell(0, 10, 'Relatório Personalizado - ' . ucfirst($module), 0, 1, 'C');
    $pdf->Ln(10);
    
    // Tabela
    $pdf->SetFont('helvetica', '', 10);
    
    $html = '<table border="1" cellspacing="0" cellpadding="3">';
    
    // Cabeçalhos
    $html .= '<tr style="background-color: #f0f0f0;">';
    foreach ($fields as $field) {
        $label = getFieldLabel($field, $dictionary);
        $html .= '<th><strong>' . htmlspecialchars($label) . '</strong></th>';
    }
    $html .= '</tr>';
    
    // Dados
    foreach ($data as $row) {
        $html .= '<tr>';
        foreach ($row as $value) {
            $html .= '<td>' . htmlspecialchars($value ?: '') . '</td>';
        }
        $html .= '</tr>';
    }
    
    $html .= '</table>';
    
    $pdf->writeHTML($html, true, false, true, false, '');
    
    // Output
    $filename = "relatorio_alunos_" . date('Y-m-d_H-i-s') . ".pdf";
    $pdf->Output($filename, 'D');
}

function getFieldLabel($field, $dictionary) {
    $parts = explode('.', $field);
    if (count($parts) !== 2) return $field;
    
    $table = $parts[0];
    $column = $parts[1];
    
    if (isset($dictionary['tables'][$table]['columns'][$column])) {
        return $dictionary['tables'][$table]['columns'][$column]['label'];
    }
    
    return $field;
}

// Incluir a classe QueryBuilder do execute_query.php
class QueryBuilder {
    private $dictionary;
    private $pdo;
    
    public function __construct($dictionary, $pdo) {
        $this->dictionary = $dictionary;
        $this->pdo = $pdo;
    }
    
    public function buildAndExecute($params) {
        try {
            // Construir SELECT
            $selectClause = $this->buildSelectClause($params['fields']);
            
            // Construir FROM e JOINs
            $fromClause = $this->buildFromClause($params['fields']);
            
            // Construir WHERE
            $whereClause = $this->buildWhereClause($params['filters']);
            
            // Construir ORDER BY
            $orderByClause = $this->buildOrderByClause($params['orderBy']);
            
            // Construir LIMIT
            $limitClause = "LIMIT " . $params['limit'] . " OFFSET " . $params['offset'];
            
            // Montar a consulta final
            $sql = "SELECT {$selectClause} FROM {$fromClause}";
            if (!empty($whereClause['sql'])) {
                $sql .= " WHERE {$whereClause['sql']}";
            }
            if (!empty($orderByClause)) {
                $sql .= " ORDER BY {$orderByClause}";
            }
            $sql .= " {$limitClause}";
            
            // Executar consulta
            $stmt = $this->pdo->prepare($sql);
            
            // Bind dos parâmetros
            foreach ($whereClause['params'] as $param => $value) {
                $stmt->bindValue($param, $value);
            }
            
            $stmt->execute();
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Contar total de registros
            $countSql = "SELECT COUNT(*) as total FROM {$fromClause}";
            if (!empty($whereClause['sql'])) {
                $countSql .= " WHERE {$whereClause['sql']}";
            }
            
            $countStmt = $this->pdo->prepare($countSql);
            foreach ($whereClause['params'] as $param => $value) {
                $countStmt->bindValue($param, $value);
            }
            $countStmt->execute();
            $totalRow = $countStmt->fetch(PDO::FETCH_ASSOC);
            
            return [
                'status' => 'success',
                'data' => $data,
                'total' => $totalRow['total']
            ];
            
        } catch (Exception $e) {
            return [
                'status' => 'error',
                'message' => 'Erro na consulta: ' . $e->getMessage()
            ];
        }
    }
    
    private function buildSelectClause($fields) {
        $selectFields = [];
        foreach ($fields as $field) {
            [$table, $column] = explode('.', $field);
            $selectFields[] = "{$table}.{$column}";
        }
        return implode(', ', $selectFields);
    }
    
    private function buildFromClause($fields) {
        $tablesUsed = [];
        foreach ($fields as $field) {
            [$table, $column] = explode('.', $field);
            $tablesUsed[$table] = true;
        }
        
        $tables = array_keys($tablesUsed);
        $mainTable = $tables[0];
        $fromClause = $mainTable;
        
        // Adicionar JOINs se necessário
        if (count($tables) > 1) {
            for ($i = 1; $i < count($tables); $i++) {
                $joinTable = $tables[$i];
                $joinInfo = $this->findJoinPath($mainTable, $joinTable);
                if ($joinInfo) {
                    $fromClause .= " {$joinInfo['type']} JOIN {$joinTable} ON {$joinInfo['condition']}";
                }
            }
        }
        
        return $fromClause;
    }
    
    private function buildWhereClause($filters) {
        $whereConditions = [];
        $params = [];
        $paramCounter = 0;
        
        foreach ($filters as $filter) {
            if (!isset($filter['field']) || !isset($filter['operator']) || !isset($filter['value'])) {
                continue;
            }
            
            [$table, $column] = explode('.', $filter['field']);
            
            // Validar se o campo existe no dicionário
            if (!isset($this->dictionary['tables'][$table]['columns'][$column])) {
                continue;
            }
            
            $columnInfo = $this->dictionary['tables'][$table]['columns'][$column];
            
            // Validar se o operador é permitido
            if (!in_array($filter['operator'], $columnInfo['allowed_operators'])) {
                continue;
            }
            
            $paramName = ":param{$paramCounter}";
            $paramCounter++;
            
            switch ($filter['operator']) {
                case 'LIKE':
                    $whereConditions[] = "{$table}.{$column} LIKE {$paramName}";
                    $params[$paramName] = '%' . $filter['value'] . '%';
                    break;
                case 'NOT LIKE':
                    $whereConditions[] = "{$table}.{$column} NOT LIKE {$paramName}";
                    $params[$paramName] = '%' . $filter['value'] . '%';
                    break;
                default:
                    $whereConditions[] = "{$table}.{$column} {$filter['operator']} {$paramName}";
                    $params[$paramName] = $filter['value'];
                    break;
            }
        }
        
        return [
            'sql' => implode(' AND ', $whereConditions),
            'params' => $params
        ];
    }
    
    private function buildOrderByClause($orderBy) {
        $orderFields = [];
        foreach ($orderBy as $order) {
            if (!isset($order['field']) || !isset($order['direction'])) {
                continue;
            }
            
            [$table, $column] = explode('.', $order['field']);
            
            // Validar se o campo existe e é ordenável
            if (!isset($this->dictionary['tables'][$table]['columns'][$column])) {
                continue;
            }
            
            $columnInfo = $this->dictionary['tables'][$table]['columns'][$column];
            if (!$columnInfo['is_sortable']) {
                continue;
            }
            
            $direction = strtoupper($order['direction']) === 'DESC' ? 'DESC' : 'ASC';
            $orderFields[] = "{$table}.{$column} {$direction}";
        }
        
        return implode(', ', $orderFields);
    }
    
    private function findJoinPath($fromTable, $toTable) {
        if (!isset($this->dictionary['relationships'])) {
            return null;
        }
        
        foreach ($this->dictionary['relationships'] as $relationship) {
            if ($relationship['from_table'] === $fromTable && $relationship['to_table'] === $toTable) {
                return $relationship;
            }
            if ($relationship['to_table'] === $fromTable && $relationship['from_table'] === $toTable) {
                // Inverter a relação
                return [
                    'type' => $relationship['type'],
                    'condition' => str_replace(
                        ["{$relationship['from_table']}.{$relationship['from_column']}", "{$relationship['to_table']}.{$relationship['to_column']}"],
                        ["{$relationship['to_table']}.{$relationship['to_column']}", "{$relationship['from_table']}.{$relationship['from_column']}"],
                        $relationship['condition']
                    )
                ];
            }
        }
        
        return null;
    }
}
?> 