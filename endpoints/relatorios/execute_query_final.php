<?php
// Desligar notices que quebram o JSON
error_reporting(E_ERROR | E_WARNING | E_PARSE);
ini_set('display_errors', 0);

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $input = file_get_contents('php://input');
        $dataInput = json_decode($input, true);
        
        if (!$dataInput) {
            throw new Exception("Dados JSON inválidos");
        }
        
        $module = isset($dataInput['module']) ? $dataInput['module'] : null;
        $selectedFields = isset($dataInput['selectedFields']) ? $dataInput['selectedFields'] : array();
        $filters = isset($dataInput['filters']) ? $dataInput['filters'] : array();
        $orderBy = isset($dataInput['orderBy']) ? $dataInput['orderBy'] : array();
        $limit = isset($dataInput['limit']) ? (int)$dataInput['limit'] : 50;
        $offset = isset($dataInput['offset']) ? (int)$dataInput['offset'] : 0;
        
        if (!$module || empty($selectedFields)) {
            throw new Exception("Módulo e campos são obrigatórios");
        }
        
        // *** CRÍTICO: Obter ID da secretaria seguindo o padrão SMECEL ***
        session_start();
        
        // Incluir conexão MySQL antiga para buscar usuário
        $connectionPath = dirname(__FILE__) . '/../../Connections/SmecelNovo.php';
        require_once($connectionPath);
        
        if (!isset($_SESSION['MM_Username']) || empty($_SESSION['MM_Username'])) {
            throw new Exception("Sessão inválida - usuário não logado");
        }
        
        $colname_UsuarioLogado = $_SESSION['MM_Username'];
        
        // Escapar o valor para SQL (função própria)
        $colname_UsuarioLogado_escaped = "'" . mysql_real_escape_string($colname_UsuarioLogado, $SmecelNovo) . "'";
        
        mysql_select_db($database_SmecelNovo, $SmecelNovo);
        $query_UsuarioLogado = "SELECT * FROM smc_usu WHERE usu_email = " . $colname_UsuarioLogado_escaped;
        $UsuarioLogado = mysql_query($query_UsuarioLogado, $SmecelNovo) or die(mysql_error());
        $row_UsuarioLogado = mysql_fetch_assoc($UsuarioLogado);
        $totalRows_UsuarioLogado = mysql_num_rows($UsuarioLogado);
        
        if ($totalRows_UsuarioLogado < 1) {
            throw new Exception("Usuário não encontrado");
        }
        
        if (!isset($row_UsuarioLogado['usu_sec']) || empty($row_UsuarioLogado['usu_sec'])) {
            throw new Exception("ID da secretaria não encontrado no perfil do usuário");
        }
        
        $secretariaId = $row_UsuarioLogado['usu_sec'];
        
        // Incluir conexão PDO
        $connectionPath = dirname(__FILE__) . '/../../Connections/SmecelNovoPDO.php';
        require_once($connectionPath);
        
        if (!isset($SmecelNovo)) {
            throw new Exception("Conexão PDO não estabelecida");
        }
        
        // Carregar dicionário
        $dictionaryPath = dirname(__FILE__) . '/../../sistema/secretaria/config/data_dictionary_' . $module . '.php';
        $dictionary = require($dictionaryPath);
        
        if (!isset($dictionary['tables'])) {
            throw new Exception("Estrutura do dicionário inválida");
        }
        
        // Construir a query
        $queryBuilder = new SecureQueryBuilder($dictionary, $SmecelNovo, $secretariaId);
        $result = $queryBuilder->buildAndExecute(array(
            'fields' => $selectedFields,
            'filters' => $filters,
            'orderBy' => $orderBy,
            'limit' => $limit,
            'offset' => $offset
        ));
        
        if ($result['status'] === 'success') {
            echo json_encode(array(
                "status" => "success",
                "data" => $result['data'],
                "total" => $result['total'],
                "fields" => $selectedFields,
                "sql" => $result['sql'],
                "secretaria_id" => $secretariaId,
                "pagination" => array(
                    "limit" => $limit,
                    "offset" => $offset,
                    "hasMore" => $result['total'] > ($offset + $limit)
                )
            ));
        } else {
            echo json_encode($result);
        }
        
    } catch (Exception $e) {
        echo json_encode(array(
            "status" => "error",
            "message" => $e->getMessage(),
            "file" => $e->getFile(),
            "line" => $e->getLine()
        ));
    }
} else {
    echo json_encode(array(
        "status" => "error",
        "message" => "Método inválido. Use POST"
    ));
}

class SecureQueryBuilder {
    private $dictionary;
    private $pdo;
    private $secretariaId;
    
    public function __construct($dictionary, $pdo, $secretariaId) {
        $this->dictionary = $dictionary;
        $this->pdo = $pdo;
        $this->secretariaId = $secretariaId;
    }
    
    public function buildAndExecute($params) {
        try {
            // Validar campos
            $validatedFields = $this->validateFields($params['fields']);
            
            // Primeiro, identificar tabelas usadas
            $tablesUsed = array();
            foreach ($validatedFields as $field) {
                $parts = explode('.', $field);
                $table = $parts[0];
                $tablesUsed[$table] = true;
            }
            
            // Adicionar tabelas dos filtros do usuário
            foreach ($params['filters'] as $filter) {
                if (isset($filter['field'])) {
                    $parts = explode('.', $filter['field']);
                    if (count($parts) === 2) {
                        $table = $parts[0];
                        $tablesUsed[$table] = true;
                    }
                }
            }
            
            // *** CRÍTICO: Adicionar filtros de sistema baseado nas tabelas usadas ***
            $allFilters = $this->addSystemFilters($params['filters'], $tablesUsed);
            
            // Construir SELECT
            $selectClause = $this->buildSelectClause($validatedFields);
            
            // Construir WHERE
            $whereClause = $this->buildWhereClause($allFilters);
            
            // Construir FROM e JOINs (agora com filtros incluídos)
            $fromClause = $this->buildFromClause($validatedFields, $allFilters);
            
            // Construir ORDER BY
            $orderByClause = $this->buildOrderByClause($params['orderBy']);
            
            // Construir LIMIT
            $limitClause = "LIMIT " . $params['limit'] . " OFFSET " . $params['offset'];
            
            // Montar SQL
            $sql = "SELECT " . $selectClause . " FROM " . $fromClause;
            if (!empty($whereClause['sql'])) {
                $sql .= " WHERE " . $whereClause['sql'];
            }
            if (!empty($orderByClause)) {
                $sql .= " ORDER BY " . $orderByClause;
            }
            $sql .= " " . $limitClause;
            
            // Executar consulta
            $stmt = $this->pdo->prepare($sql);
            
            // Bind parâmetros
            if (!empty($whereClause['params'])) {
                foreach ($whereClause['params'] as $param => $value) {
                    $stmt->bindValue($param, $value);
                }
            }
            
            $stmt->execute();
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Contar total
            $countSql = "SELECT COUNT(*) as total FROM " . $fromClause;
            if (!empty($whereClause['sql'])) {
                $countSql .= " WHERE " . $whereClause['sql'];
            }
            
            $countStmt = $this->pdo->prepare($countSql);
            if (!empty($whereClause['params'])) {
                foreach ($whereClause['params'] as $param => $value) {
                    $countStmt->bindValue($param, $value);
                }
            }
            
            $countStmt->execute();
            $totalRow = $countStmt->fetch(PDO::FETCH_ASSOC);
            
            return array(
                'status' => 'success',
                'data' => $data,
                'total' => $totalRow['total'],
                'sql' => $sql
            );
            
        } catch (Exception $e) {
            return array(
                'status' => 'error',
                'message' => 'Erro na consulta: ' . $e->getMessage()
            );
        }
    }
    
    // *** MÉTODO CRÍTICO: Adicionar filtros de sistema ***
    private function addSystemFilters($userFilters, $tablesUsed) {
        $allFilters = $userFilters;
        
        // *** GARANTIR QUE O VÍNCULO SEJA INCLUÍDO PARA FILTRO DE SEGURANÇA ***
        $tablesUsed['smc_vinculo_aluno'] = true;
        
        // Adicionar filtro de segurança no vínculo (sempre)
        $allFilters[] = [
            'field' => 'smc_vinculo_aluno.vinculo_aluno_id_sec',
            'operator' => '=',
            'value' => $this->secretariaId,
            'is_system_filter' => true
        ];
        
        return $allFilters;
    }
    
    private function validateFields($fields) {
        $validatedFields = array();
        
        foreach ($fields as $field) {
            $parts = explode('.', $field);
            if (count($parts) !== 2) {
                throw new Exception("Formato de campo inválido: " . $field);
            }
            
            $table = $parts[0];
            $column = $parts[1];
            
            if (!isset($this->dictionary['tables'][$table])) {
                throw new Exception("Tabela inválida: " . $table);
            }
            
            if (!isset($this->dictionary['tables'][$table]['columns'][$column])) {
                throw new Exception("Coluna inválida: " . $column . " na tabela " . $table);
            }
            
            $validatedFields[] = $table . '.' . $column;
        }
        
        return $validatedFields;
    }
    
    private function buildSelectClause($fields) {
        $selectParts = array();
        
        foreach ($fields as $field) {
            $parts = explode('.', $field);
            $table = $parts[0];
            $column = $parts[1];
            
            $columnInfo = $this->dictionary['tables'][$table]['columns'][$column];
            
            // Verificar se tem SQL customizado
            if (isset($columnInfo['custom_sql'])) {
                $alias = isset($columnInfo['alias']) ? $columnInfo['alias'] : $column;
                $selectParts[] = '(' . $columnInfo['custom_sql'] . ') as ' . $alias;
            } else {
                $alias = isset($columnInfo['alias']) ? $columnInfo['alias'] : $column;
                $selectParts[] = $table . '.' . $column . ' as ' . $alias;
            }
        }
        
        return implode(', ', $selectParts);
    }
    
    private function buildFromClause($fields, $filters = []) {
        // Tabela principal: sempre começar com smc_aluno
        $mainTable = 'smc_aluno';
        
        // Identificar todas as tabelas necessárias
        $tablesNeeded = array();
        
        // Tabelas dos campos
        foreach ($fields as $field) {
            $parts = explode('.', $field);
            $table = $parts[0];
            $tablesNeeded[$table] = true;
        }
        
        // Tabelas dos filtros
        foreach ($filters as $filter) {
            if (isset($filter['field'])) {
                $parts = explode('.', $filter['field']);
                if (count($parts) === 2) {
                    $table = $parts[0];
                    $tablesNeeded[$table] = true;
                }
            }
        }
        
        // Construir FROM com JOINs na ordem correta
        $fromClause = $mainTable;
        
        // Sempre fazer JOIN com smc_vinculo_aluno se necessário
        if (isset($tablesNeeded['smc_vinculo_aluno'])) {
            $fromClause .= ' LEFT JOIN smc_vinculo_aluno ON smc_aluno.aluno_id = smc_vinculo_aluno.vinculo_aluno_id_aluno';
        }
        
        // JOIN com smc_turma se necessário
        if (isset($tablesNeeded['smc_turma'])) {
            if (!isset($tablesNeeded['smc_vinculo_aluno'])) {
                // Precisa adicionar vínculo para chegar na turma
                $fromClause .= ' LEFT JOIN smc_vinculo_aluno ON smc_aluno.aluno_id = smc_vinculo_aluno.vinculo_aluno_id_aluno';
            }
            $fromClause .= ' LEFT JOIN smc_turma ON smc_vinculo_aluno.vinculo_aluno_id_turma = smc_turma.turma_id';
        }
        
        // JOIN com smc_escola se necessário
        if (isset($tablesNeeded['smc_escola'])) {
            // Precisa da turma para chegar na escola
            if (!isset($tablesNeeded['smc_turma'])) {
                if (!isset($tablesNeeded['smc_vinculo_aluno'])) {
                    $fromClause .= ' LEFT JOIN smc_vinculo_aluno ON smc_aluno.aluno_id = smc_vinculo_aluno.vinculo_aluno_id_aluno';
                }
                $fromClause .= ' LEFT JOIN smc_turma ON smc_vinculo_aluno.vinculo_aluno_id_turma = smc_turma.turma_id';
            }
            $fromClause .= ' LEFT JOIN smc_escola ON smc_turma.turma_id_escola = smc_escola.escola_id';
        }
        
        return $fromClause;
    }
    
    private function buildWhereClause($filters) {
        $whereConditions = array();
        $params = array();
        $paramCount = 0;
        
        foreach ($filters as $filter) {
            if (!isset($filter['field']) || !isset($filter['operator']) || !isset($filter['value'])) {
                continue;
            }
            
            $field = $filter['field'];
            $operator = $filter['operator'];
            $value = $filter['value'];
            
            // Validar operador
            $validOperators = ['=', '!=', '>', '<', '>=', '<=', 'LIKE', 'NOT LIKE', 'IN', 'NOT IN'];
            if (!in_array($operator, $validOperators)) {
                throw new Exception("Operador inválido: " . $operator);
            }
            
            if ($operator === 'IN' || $operator === 'NOT IN') {
                // Operador IN/NOT IN com array de valores
                if (is_array($value) && count($value) > 0) {
                    $placeholders = array();
                    foreach ($value as $val) {
                        $paramName = ':param' . $paramCount++;
                        $placeholders[] = $paramName;
                        $params[$paramName] = $val;
                    }
                    $whereConditions[] = $field . ' ' . $operator . ' (' . implode(', ', $placeholders) . ')';
                } else {
                    // Se não for array ou estiver vazio, tratar como valor único
                    $paramName = ':param' . $paramCount++;
                    $whereConditions[] = $field . ' ' . $operator . ' (' . $paramName . ')';
                    $params[$paramName] = $value;
                }
            } else if ($operator === 'LIKE' || $operator === 'NOT LIKE') {
                $paramName = ':param' . $paramCount++;
                $whereConditions[] = $field . ' ' . $operator . ' ' . $paramName;
                $params[$paramName] = '%' . $value . '%';
            } else {
                $paramName = ':param' . $paramCount++;
                $whereConditions[] = $field . ' ' . $operator . ' ' . $paramName;
                $params[$paramName] = $value;
            }
        }
        
        return array(
            'sql' => implode(' AND ', $whereConditions),
            'params' => $params
        );
    }
    
    private function buildOrderByClause($orderBy) {
        if (empty($orderBy)) {
            return '';
        }
        
        $orderParts = array();
        
        foreach ($orderBy as $order) {
            if (!isset($order['field']) || !isset($order['direction'])) {
                continue;
            }
            
            $field = $order['field'];
            $direction = strtoupper($order['direction']);
            
            if ($direction !== 'ASC' && $direction !== 'DESC') {
                $direction = 'ASC';
            }
            
            $orderParts[] = $field . ' ' . $direction;
        }
        
        return implode(', ', $orderParts);
    }
}
?> 