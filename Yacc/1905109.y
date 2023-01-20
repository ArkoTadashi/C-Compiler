%{
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cmath>
#include "SymbolTable.cpp"

using namespace std;


int yyparse(void);
int yylex(void);

extern FILE *yyin;
extern int line_count;

ofstream errout;
ofstream logout;
ofstream parseout;

SymbolTable *table = new SymbolTable(109);
int err_count = 0;

vector<SymbolInfo*>* parameterList = new vector<SymbolInfo*>;
vector<SymbolInfo*>* declareList = new vector<SymbolInfo*>;

void yyerror(const char* s) {
	cout<<"Error at line "<<line_count<<": "<<s<<"\n"<<endl;
	//errout<<"Error at line "<<line_count<<": "<<s<<"\n"<<endl;
	err_count++;
}

void debug(string s) {
	cout<<"debug: Line "<<line_count<<": "<<s<<endl<<endl;
}

void printErr(string s, int line_cnt = -1) {
	errout<<"Error at line "<<(line_cnt == -1 ? line_count:line_cnt)<<": "<<s<<"\n"<<endl;
	cout<<"Error at line "<<(line_cnt == -1 ? line_count:line_cnt)<<": "<<s<<"\n"<<endl;
	err_count++;
}

void printLog(string rule, string out = "") {
	logout <<"Line# " << line_count << ": " << rule << endl;
}



void callFunction(SymbolInfo* &funcSym, vector<SymbolInfo*>* args = NULL) {
	// string funcName = funcSym->getName();
	// SymbolInfo* symbol = table->look_up(funcName);
	// if(symbol == NULL) {
	// 	printErr("Undeclared Function " + funcName);
	// 	return;
	// }
	// if(!symbol->isFunction()) {
	// 	printErr(funcName + " is not a function");
	// 	return;
	// }
	// funcSym->setReturnType(symbol->getReturnType());
	// if(symbol->getInfoType() != SymbolInfo::FUNCTION_DEFINITION) {
	// 	printErr("Function " + funcName+" not defined");
	// 	return;
	// }
	// vector<pair<string, string> > params = symbol->getParameters();
	// int paramCnt = args == NULL ? 0 : args->size();
	// if(params.size() != paramCnt) {
	// 	printErr("Total number of arguments mismatch in function " + funcName);
	// 	return;
	// }
	// if(args != NULL) {
	// 	vector<SymbolInfo*> argList = *args;
	// 	for(int i = 0; i < params.size(); i++) {
	// 		if(params[i].first != argList[i]->getDataType()) {
	// 			printErr(to_string(i+1) + "th argument mismatch in function " + funcName);
	// 			return;
	// 		}
	// 	}
	// }
}


void checkVoidFunc(SymbolInfo* symbol1, SymbolInfo* symbol2) {
	// if(symbol1->getDataType() == "void" || symbol2->getDataType() == "void"){
	// 	printErr("Void function used in expression");
	// }
}

void deleteTree(SymbolInfo* parent) {
    for(SymbolInfo* symbol : *parent->getChildList()) {
        deleteTree(symbol);
        delete symbol;
    }
    delete parent->getChildList();
}



%}

%union{
	SymbolInfo* symbolInfo;
}

%token<symbolInfo> IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID BITOP INCOP DECOP ASSIGNOP NOT RETURN LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON SWITCH CASE DEFAULT CONTINUE PRINTLN STRING 
%token<symbolInfo> ADDOP MULOP RELOP LOGICOP CONST_INT CONST_FLOAT CONST_CHAR ID

%type<symbolInfo> type_specifier factor expression unary_expression simple_expression expression_statement term rel_expression logic_expression start program unit func_declaration func_definition compound_statement var_declaration statement statements variable
%type<symbolInfo> declaration_list parameter_list argument_list arguments

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
    
start : program {
		printLog("start : program");
		$$ = new SymbolInfo("start", "program");
		
		table->printAll(logout); 
		
		table->closeScope();
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
        $$->printChild(0, parseout);
        // deleteTree($$);
		cout << "Total Lines: " << line_count << endl;
		cout << "Total Errors: " << err_count << endl;
	}
	;
program : program unit {
		printLog("program : program unit");
		$$ = new SymbolInfo("program", "program unit");
		$$->addChild($1);
        $$->addChild($2);
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($2->getEndLine());
	}
	| unit {
		printLog("program : unit");
		$$ = new SymbolInfo("program", "unit");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
	;

unit : var_declaration {
		printLog("unit : var_declaration");
		$$ = new SymbolInfo("unit", "var_declaration");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
    | func_declaration {
		printLog("unit : func_declaration");
		$$ = new SymbolInfo("unit", "func_declaration");
		$$->setStartLine($1->getStartLine());
        $$->setEndLine($1->getEndLine());
        $$->addChild($1);
	}
    | func_definition {
		printLog("unit : func_definition");
		$$ = new SymbolInfo("unit", "func_definition");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
        
	}
    ;

func_declaration : type_specifier ID LPAREN parameter_list RPAREN {
				$2->setParameters(parameterList);
				$2->setInfoType(SymbolInfo::FUNCTION_DECLARATION);
			} SEMICOLON {
		printLog("func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| type_specifier ID LPAREN RPAREN SEMICOLON {
		printLog("func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON");
		$$ = new SymbolInfo("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	;
func_definition : type_specifier ID LPAREN parameter_list RPAREN {
				$2->setParameters(parameterList);
				$2->setInfoType(SymbolInfo::FUNCTION_DEFINITION);
			} 
			compound_statement {
		printLog("func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN parameter_list RPAREN compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
		
	}
	| type_specifier ID LPAREN RPAREN compound_statement {
		printLog("func_definition : type_specifier ID LPAREN RPAREN compound_statement");
		$$ = new SymbolInfo("func_definition", "type_specifier ID LPAREN RPAREN compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	;

parameter_list : parameter_list COMMA type_specifier ID {
		printLog("parameter_list : parameter_list COMMA type_specifier ID");
		$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		SymbolInfo* symbol = new SymbolInfo($4->getName(), $3->getType());
		parameterList->push_back(symbol);
	}
	| parameter_list COMMA type_specifier {
		printLog("parameter_list : parameter_list COMMA type_specifier");
		$$ = new SymbolInfo("parameter_list", "parameter_list COMMA type_specifier");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		SymbolInfo* symbol = new SymbolInfo("", $3->getType());
		parameterList->push_back(symbol);
	}
	| type_specifier ID {
		printLog("parameter_list : type_specifier ID");
		$$ = new SymbolInfo("parameter_list", "type_specifier ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		SymbolInfo* symbol = new SymbolInfo($2->getName(), $1->getType());
		parameterList->push_back(symbol);
	}
	| type_specifier {
		printLog("parameter_list : type_specifier");
		$$ = new SymbolInfo("parameter_list", "type_specifier");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		SymbolInfo* symbol = new SymbolInfo("", $1->getType());
		parameterList->push_back(symbol);
	}
	;

compound_statement : LCURL {
					table->newScope();  //////////////////////////////////////////////////////////////////////////////
					for (SymbolInfo* symbol : *parameterList) {
						bool inserted = table->insert(symbol->getName(), symbol->getType());
						if(!inserted) {
							printErr("Redifinition of Parameter");
							continue;
						}
					}
					parameterList->clear();
				} 
				statements RCURL {
		printLog("compound_statement : LCURL statements RCURL");
		$$ = new SymbolInfo("compound_statement", "LCURL statements RCURL");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		table->printAll(logout);
		table->closeScope();
	}
	| LCURL {
				table->newScope(); //////////////////////////////////////////////////////////////////////////////////////////////
				for (SymbolInfo* symbol : *parameterList) {
					bool inserted = table->insert(symbol->getName(), symbol->getType());
					if(!inserted) {
						printErr("Redifinition of Parameter");
						continue;
					}
				}
				parameterList->clear();
			} 
			RCURL {
		printLog("compound_statement : LCURL RCURL");
		$$ = new SymbolInfo("compound_statement", "LCURL RCURL");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
		table->printAll(logout);
		table->closeScope();
	}
	;

var_declaration : type_specifier declaration_list SEMICOLON {
		printLog("var_declaration : type_specifier declaration_list SEMICOLON");
		for (SymbolInfo* symbol : *declareList) {
			symbol->setDataType($1->getType());
			if ($1->getType() == "void") {
				printErr("VOID VOID VOID VOID");
				continue;
			}
			bool inserted = table->insert(symbol->getName(), symbol->getType());
			if (!inserted) {
				printErr("Multiple declaration");
				continue;
			}
		}
		declareList->clear();
		$$ = new SymbolInfo("var_declaration", "type_specifier declaration_list SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	;

type_specifier : INT {
		printLog("type_specifier : INT");
		$$ = new SymbolInfo("type_specifier", "INT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		
	}
	| FLOAT {
		printLog("type_specifier : FLOAT");
		$$ = new SymbolInfo("type_specifier", "FLOAT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| VOID {
		printLog("type_specifier : VOID");
		$$ = new SymbolInfo("type_specifier", "VOID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	;

declaration_list : declaration_list COMMA ID {
		printLog("declaration_list : declaration_list COMMA ID");
		$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
		declareList->push_back($3);
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD {
		printLog("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("declaration_list", "declaration_list COMMA ID LTHIRD CONST_INT RTHIRD");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
        $$->setEndLine($6->getEndLine());
		SymbolInfo* symbol = new SymbolInfo($3->getName(), "ARRAY");
		symbol->setArraySize(stoi($5->getName()));
		declareList->push_back(symbol);
	}
	| ID {
		printLog("declaration_list : ID");
		$$ = new SymbolInfo("declaration_list", "ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
		declareList->push_back($1);
	}
	| ID LTHIRD CONST_INT RTHIRD {
		printLog("declaration_list : ID LTHIRD CONST_INT RTHIRD");
		$$ = new SymbolInfo("declaration_list", "ID LTHIRD CONST_INT RTHIRD");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
		SymbolInfo* symbol = new SymbolInfo($1->getName(), "ARRAY");
		symbol->setArraySize(stoi($3->getName()));
		declareList->push_back(symbol);
	}
	;
	
statements : statement {
		printLog("statements : statement");
		$$ = new SymbolInfo("statements", "statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| statements statement {
		printLog("statements : statements statement");
		$$ = new SymbolInfo("statements", "statements statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}
	;
statement : var_declaration {
		printLog("statement : var_declaration");
		$$ = new SymbolInfo("statement", "var_declaration");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}	
	| expression_statement {
		printLog("statement : expression_statement");
		$$ = new SymbolInfo("statement", "expression_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| compound_statement {
		printLog("statement : compound_statement");
		$$ = new SymbolInfo("statement", "compound_statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement {
		printLog("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$ = new SymbolInfo("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE {
		printLog("statement : IF LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| IF LPAREN expression RPAREN statement ELSE statement {
		printLog("statement : IF LPAREN expression RPAREN statement ELSE statement");
		$$ = new SymbolInfo("statement", "IF LPAREN expression RPAREN statement ELSE statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
		$$->addChild($6);
		$$->addChild($7);
        $$->setEndLine($7->getEndLine());
	}
	| WHILE LPAREN expression RPAREN statement {
		printLog("statement : WHILE LPAREN expression RPAREN statement");
		$$ = new SymbolInfo("statement", "WHILE LPAREN expression RPAREN statement");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON {
		printLog("statement : PRINTLN LPAREN ID RPAREN SEMICOLON");
		if(!table->look_up($3->getName())){
			printErr("Undeclared variable " + $3->getName());
		}
		$$ = new SymbolInfo("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->addChild($5);
        $$->setEndLine($5->getEndLine());
	}
	| RETURN expression SEMICOLON {
		printLog("statement : RETURN expression SEMICOLON");
		$$ = new SymbolInfo("statement", "RETURN expression SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	;

expression_statement : SEMICOLON {
		printLog("expression_statement : SEMICOLON");
		$$ = new SymbolInfo("expression_statement", "SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}			
	| expression SEMICOLON {
		printLog("expression_statement : expression SEMICOLON");
		$$ = new SymbolInfo("expression_statement", "expression SEMICOLON");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}
	;

variable : ID { 
		printLog("variable : ID");
		
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) {
			if(symbol->isArray()) {
				printErr("Type mismatch, " + symbol->getName() + " is an array");
			}
		}
		else {
			printErr("Undeclared variable " + $1->getName());
		}
		$$ = new SymbolInfo("variable", "ID");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
	}
	| ID LTHIRD expression RTHIRD {
		printLog("variable : ID LTHIRD expression RTHIRD");
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) { 
			$1->setDataType(symbol->getDataType());
			if(!symbol->isArray()) { 
				printErr($1->getName() + " is not an array.");
			}
			if($3->getDataType() != "int") {
				printErr("Expression inside third brackets not an integer");
			}
		}
		else {
			printErr("Undeclared variable " + $1->getName());
		}
		$$ = new SymbolInfo("variable", "ID LTHIRD expression RTHIRD");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
		$$->setEndLine($4->getEndLine());
	}
	;

expression : logic_expression {
		printLog("expression : logic_expression");
		$$ = new SymbolInfo("expression", "logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
	}
	| variable ASSIGNOP logic_expression {
		printLog("expression : variable ASSIGNOP logic_expression");
		SymbolInfo *symbol = table->look_up($1->getName());
		if(symbol != NULL) {
			if(symbol->getDataType() == "int" && $3->getDataType() == "float") {
				printErr("Type mismatch");
			}
		}
		if($3->getDataType() == "void") {
				printErr("Void function used in expression");
		}
		$$ = new SymbolInfo("expression", "variable ASSIGNOP logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
	}	
	;

logic_expression : rel_expression { 
		printLog("logic_expression : rel_expression");
		$$ = new SymbolInfo("logic_expression", "rel_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
	}	
	| rel_expression LOGICOP rel_expression {
		printLog("logic_expression : rel_expression LOGICOP rel_expression");
		$$ = new SymbolInfo("logic_expression", "rel_expression LOGICOP rel_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
	}	
	;

rel_expression : simple_expression {
		printLog("rel_expression : simple_expression");
		$$ = new SymbolInfo("rel_expression", "simple_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
	}
	| simple_expression RELOP simple_expression	{
		printLog("rel_expression : simple_expression RELOP simple_expression");
		$$ = new SymbolInfo("rel_expression", "simple_expression RELOP simple_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
	}
	;

simple_expression : term {
		printLog("simple_expression : term");
		$$ = new SymbolInfo("simple_expression", "term");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->setEndLine($1->getEndLine());
	}	
	| simple_expression ADDOP term {
		printLog("simple_expression : simple_expression ADDOP term");
		// checkVoidFunc($1, $3);
		$$ = new SymbolInfo("simple_expression", " : simple_expression ADDOP term");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->setEndLine($3->getEndLine());
	} 
	;

term : unary_expression {
		printLog("term : unary_expression");
		$$ = new SymbolInfo("term", "unary_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
    |  term MULOP unary_expression {
		printLog("term : term MULOP unary_expression");
		// checkVoidFunc($1, $3);
		if($2->getName() == "%"){
			if($3->getName() == "0") printErr("Modulus by Zero");
			if($1->getDataType() != "int" || $3->getDataType() != "int"){
				printErr("Non-Integer operand on modulus operator");
			}
			$1->setDataType("int");
			$3->setDataType("int");
		}
		$$ = new SymbolInfo("term", "term MULOP unary_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
    ;

unary_expression : ADDOP unary_expression {
		printLog("unary_expression : ADDOP unary_expression");
		$$ = new SymbolInfo("unary_expression", "ADDOP unary_expression");
		$$ = new SymbolInfo();
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}  
	| NOT unary_expression {
		printLog("unary_expression : NOT unary_expression");
		$$ = new SymbolInfo("unary_expression", "NOT unary_expression");
		$$ = new SymbolInfo();
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	} 
	| factor {
		printLog("unary_expression : factor");
		$$ = new SymbolInfo("unary_expression", "factor");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());

	} 
	;
	

factor : variable {
		printLog("factor : variable");
		$$ = new SymbolInfo("factor", "variable");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| ID LPAREN argument_list RPAREN { 
		printLog("factor : ID LPAREN argument_list RPAREN");
		//callFunction($1, $3);
		$$ = new SymbolInfo("factor", "ID LPAREN argument_list RPAREN");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
		$$->addChild($4);
        $$->setEndLine($4->getEndLine());
	}
	| LPAREN expression RPAREN {
		printLog("factor : LPAREN expression RPAREN");
		$$ = new SymbolInfo("factor", "LPAREN expression RPAREN");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	| CONST_INT {
		printLog("factor : CONST_INT");
		$$ = new SymbolInfo("factor", "CONST_INT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| CONST_FLOAT { 
		printLog("factor : CONST_FLOAT");
		$$ = new SymbolInfo("factor", "CONST_FLOAT");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	| variable INCOP {
		printLog("factor : variable INCOP");
		$$ = new SymbolInfo("factor", "variable INCOP");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}
	| variable DECOP {
		printLog("factor : variable DECOP");
		$$ = new SymbolInfo("factor", "variable DECOP");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
        $$->setEndLine($2->getEndLine());
	}
	;
	
argument_list : arguments {
		printLog("argument_list : arguments");
		$$ = new SymbolInfo("argument_list", "arguments");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	|
	{
		printLog("argument_list : arguments");
		$$ = new SymbolInfo("argument_list", "arguments");
	}
	;
	
arguments : arguments COMMA logic_expression {
		printLog("arguments : arguments COMMA logic_expression");
		$$ = new SymbolInfo("arguments", "arguments COMMA logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
		$$->addChild($2);
		$$->addChild($3);
        $$->setEndLine($3->getEndLine());
	}
	| logic_expression {
		printLog("arguments : logic_expression");
		$$ = new SymbolInfo("arguments", "logic_expression");
		$$->setStartLine($1->getStartLine());
		$$->addChild($1);
        $$->setEndLine($1->getEndLine());
	}
	;
%%


int main(int argc,char *argv[]) {

	FILE* fp;
	if((fp = freopen(argv[1], "r", stdin)) == NULL) {
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	parseout.open("parsetree.txt");
	logout.open("log.txt");
	errout.open("error.txt");
	
	yyin = fp;
	line_count = 1;
	yyparse();
	
	fclose(yyin);
	
	return 0;
}

