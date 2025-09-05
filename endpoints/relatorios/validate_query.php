<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $dataInput = json_decode(file_get_contents('php://input'), true);
    
    $module = isset($dataInput['module']) ? $dataInput['module'] : null;
    $selectedFields = isset($dataInput['selectedFields']) ? $dataInput['selectedFields'] : [];
    $filters = isset($dataInput['filters']) ? $dataInput['filters'] : [];
    
    if (!$module) {
        echo json_encode(["status" => "error", "message" => "Módulo é obrigatório"]);
        exit;
    }
    
    try {
        // Carregar o dicionário de dados
        $dictionaryPath = "../../sistema/secretaria/config/data_dictionary_{$module}.php";
        
        if (!file_exists($dictionaryPath)) {
            echo json_encode(["status" => "error", "message" => "Dicionário de dados não encontrado"]);
            exit;
        }
        
        $dictionary = require($dictionaryPath);
        $validator = new QueryValidator($dictionary);
        
        $validationResult = $validator->validate([
            'fields' => $selectedFields,
            'filters' => $filters
        ]);
        
        echo json_encode($validationResult);
        
    } catch (Exception $e) {
        echo json_encode(["status" => "error", "message" => "Erro no servidor: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Método inválido. Use POST"]);
}

/**
 * Classe para validar consultas
 */
class QueryValidator {
    private $dictionary;
    
    public function __construct($dictionary) {
        $this->dictionary = $dictionary;
    }
    
    public function validate($params) {
        $errors = [];
        $warnings = [];
        
        // Validar campos
        if (empty($params['fields'])) {
            $errors[] = "Pelo menos um campo deve ser selecionado";
        } else {
            foreach ($params['fields'] as $field) {
                $fieldValidation = $this->validateField($field);
                if (!$fieldValidation['valid']) {
                    $errors[] = $fieldValidation['message'];
                }
            }
        }
        
        // Validar filtros
        foreach ($params['filters'] as $filter) {
            $filterValidation = $this->validateFilter($filter);
            if (!$filterValidation['valid']) {
                $errors[] = $filterValidation['message'];
            }
        }
        
        // Verificar se há muitos campos selecionados
        if (count($params['fields']) > 20) {
            $warnings[] = "Muitos campos selecionados. Isso pode impactar a performance.";
        }
        
        return [
            'status' => empty($errors) ? 'success' : 'error',
            'valid' => empty($errors),
            'errors' => $errors,
            'warnings' => $warnings
        ];
    }
    
    private function validateField($field) {
        $parts = explode('.', $field);
        if (count($parts) !== 2) {
            return ['valid' => false, 'message' => "Formato de campo inválido: {$field}"];
        }
        
        [$table, $column] = $parts;
        
        if (!isset($this->dictionary['tables'][$table])) {
            return ['valid' => false, 'message' => "Tabela não autorizada: {$table}"];
        }
        
        if (!isset($this->dictionary['tables'][$table]['columns'][$column])) {
            return ['valid' => false, 'message' => "Coluna não autorizada: {$field}"];
        }
        
        return ['valid' => true, 'message' => ''];
    }
    
    private function validateFilter($filter) {
        if (!isset($filter['field']) || !isset($filter['operator']) || !isset($filter['value'])) {
            return ['valid' => false, 'message' => 'Filtro incompleto'];
        }
        
        $fieldValidation = $this->validateField($filter['field']);
        if (!$fieldValidation['valid']) {
            return $fieldValidation;
        }
        
        [$table, $column] = explode('.', $filter['field']);
        $columnInfo = $this->dictionary['tables'][$table]['columns'][$column];
        
        if (!$columnInfo['is_filterable']) {
            return ['valid' => false, 'message' => "Campo não filtrável: {$filter['field']}"];
        }
        
        if (!in_array($filter['operator'], $columnInfo['allowed_operators'])) {
            return ['valid' => false, 'message' => "Operador não permitido: {$filter['operator']} para {$filter['field']}"];
        }
        
        return ['valid' => true, 'message' => ''];
    }
}
?> 