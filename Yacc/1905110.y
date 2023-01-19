%{

#include<bits/stdc++.h>
#include"1905110_SymbolTable.h"
#include"1905110_SymbolInfo.h"
#include"1905110_ScopeTable.h"

using namespace std;
typedef long long ll;

ofstream logout;
ofstream errout;
ofstream parsetree;

extern int line_count,interal_line,error;
extern FILE *yyin;



SymbolTable *symTable = new SymbolTable(12);
ScopeTable *sc = symTable->EnterScope();
vector<SymbolInfo> parameter; 
vector<SymbolInfo> declaredVar;
int parameterNum = 0;

int yylex(void);

void yyerror( string s){
	//printf("%s\n",s);
}
void UndeclaredVariable(string name){
    SymbolInfo *s = NULL;
    s = symTable->LookUp(name);  
    if(s==NULL){
        errout<<"Line# "<<line_count<<" : "<<"Undeclared variable "<<name<< "\n";
    } 
}

void freeVector(vector<SymbolInfo*>*symInfo){
    for(SymbolInfo* info: *symInfo){
		delete info;
	}
	delete symInfo;
}

void destroyChild(SymbolInfo* parent){
    for(SymbolInfo* info : *parent->get_child()){
        destroyChild(info);
        delete info;
    }
    delete parent->get_child();
}

%}

%union{
    SymbolInfo *symInfo;
    
}

%token<symInfo> DO CHAR IF FOR ELSE INT FLOAT VOID BREAK DOUBLE PRINTLN RETURN SWITCH CASE DEFAULT WHILE CONTINUE NEWLINE SEMICOLON LPAREN RPAREN LCURL RCURL LSQUARE RSQUARE COMMA NOT DECOP RELOP ASSIGNOP INCOP
%token<symInfo> ADDOP MULOP CONST_INT CONST_FLOAT LOGICOP BITOP ID
%type<symInfo> argument_list factor expression unary_expression simple_expression expression_statement term rel_expression logic_expression arguments start program unit func_in func_declaration func_definition parameter_list compound_statement var_declaration statement statements variable
%type<symInfo> type_specifier LCURL_
%type<symInfo> declaration_list

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%%
start: program          
       {
         logout<<"start : program\n";
          $$ = new SymbolInfo("start","program");
          $$->set_start($1->get_start());
          $$->set_end($1->get_end());
          $$->set_child($1);

          $$->printChild(0,parsetree);
          
          destroyChild($$);
       }
     ;
program: program unit   
        {
            logout<<"program : program unit\n";
            $$ = new SymbolInfo("program","program unit");
            
            $$->set_child($1);
            $$->set_child($2);

            $$->set_start($1->get_start());
            $$->set_end($2->get_end());
        }
    | unit              
        {
            logout<<"program : unit\n";
            $$ = new SymbolInfo("program","unit");
            $$->set_start($1->get_start());
            $$->set_end($1->get_end());
            $$->set_child($1);
        }
    ; 
unit : var_declaration  
        {
            logout<<"unit : var_declaration\n";
            $$ = new SymbolInfo("unit","var_declaration");
            $$->set_start($1->get_start());
            $$->set_end($1->get_end());
            $$->set_child($1);
        }
    | func_declaration  
        {
            logout<<"unit : func_declaration\n";
            $$ = new SymbolInfo("unit","func_declaration");
            $$->set_start($1->get_start());
            $$->set_end($1->get_end());
            $$->set_child($1);
        }
    | func_definition   
        {
            logout<<"unit : func_definition\n";
            $$ = new SymbolInfo("unit","func_definition");
            $$->set_start($1->get_start());
            $$->set_end($1->get_end());
            $$->set_child($1);
        }
    ;


func_in : type_specifier ID LPAREN
          {
            symTable->Insert(($2->get_name()),"FUNCTION",$1->get_type(),logout);
          
            $$ = new SymbolInfo(($2->get_name()),$1->get_returnType());

            
            $$->set_child($1);
            $$->set_child($2);
            $$->set_child($3);

            $$->set_start($1->get_start());
            $$->set_end($3->get_end());

          }
        ;

func_declaration: func_in parameter_list RPAREN SEMICOLON {
                                                              logout<<"func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON\n";
                                                              SymbolInfo *s = symTable->LookUp(($1->get_name()));
                                                              s->set_param(parameter);
                                                              parameter.clear();

                                                              $$ = new SymbolInfo("func_declaration","type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
                                                              
                                                              vector<SymbolInfo*>* sI = $1->get_child();

                                                              for(SymbolInfo* info : *sI ){
                                                                $$->set_child(info);
                                                              }

                                                              $$->set_child($2);
                                                              $$->set_child($3);
                                                              $$->set_child($4);

                                                              $$->set_start($1->get_start());
                                                              $$->set_end($4->get_end());

                                                          }
                | func_in RPAREN SEMICOLON                {
                                                              logout<<"func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON\n";
                                                              SymbolInfo *s = symTable->LookUp(($1->get_name()));
                                                              s->set_param(parameter);
                                                              parameter.clear();

                                                              $$ = new SymbolInfo("func_declaration","type_specifier ID LPAREN RPAREN SEMICOLON");
                                                              $$->set_start($1->get_start());
                                                              $$->set_end($1->get_end());
                                                              
                                                              vector<SymbolInfo*>* sI = $1->get_child();

                                                              for(SymbolInfo* info : *sI ){
                                                                $$->set_child(info);
                                                              }

                                                              $$->set_child($2);
                                                              $$->set_child($3);
                                                              

                                                              $$->set_start($1->get_start());
                                                              $$->set_end($3->get_end());

                                                          }
                ;
func_definition : func_in parameter_list RPAREN compound_statement 
                  {
                     SymbolInfo *s = symTable->LookUp(($1->get_name()));
                     s->set_param(parameter);
                     parameter.clear();
                     logout<<"func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement\n";

                     $$ = new SymbolInfo("func_definition","type_specifier ID LPAREN parameter_list RPAREN compound_statement");
                    
                     
                     vector<SymbolInfo*>* sI = $1->get_child();
                     for(SymbolInfo* info : *sI ){
                       $$->set_child(info);
                     }
                     $$->set_child($2);
                     $$->set_child($3);
                     $$->set_child($4);

                     $$->set_start($1->get_start());
                     $$->set_end($4->get_end());
                     
                  }
                | func_in RPAREN compound_statement                
                  {  
                     SymbolInfo *s = symTable->LookUp(($1->get_name()));
                     s->set_param(parameter);
                     parameter.clear(); 
                     logout<<"func_definition : type_specifier ID LPAREN RPAREN compound_statement\n";     

                     $$ = new SymbolInfo("func_definition","type_specifier ID LPAREN RPAREN compound_statement");
                    
                     
                     vector<SymbolInfo*>* sI = $1->get_child();
                     for(SymbolInfo* info : *sI ){
                       $$->set_child(info);
                     }
                     $$->set_child($2);
                     $$->set_child($3);

                     $$->set_start($1->get_start());
                     $$->set_end($3->get_end());                                     
                  }
                ;

                
parameter_list  : parameter_list COMMA type_specifier ID 
                    {
                        parameter.push_back(SymbolInfo(($4->get_name()),$3->get_returnType()));
                        logout<<"parameter_list : parameter_list COMMA type_specifier ID\n";

                        $$ = new SymbolInfo("parameter_list","parameter_list COMMA type_specifier ID");
                        $$->set_child($1);
                        $$->set_child($2);
                        $$->set_child($3);
                        $$->set_child($4);

                        $$->set_start($1->get_start());
                        $$->set_end($4->get_end());
                    }
                | parameter_list COMMA type_specifier     
                    {
                        parameter.push_back(SymbolInfo("",$3->get_returnType()));
                        logout<<"parameter_list : parameter_list COMMA type_specifier\n";

                        $$ = new SymbolInfo("parameter_list","parameter_list COMMA type_specifier");
                        $$->set_child($1);
                        $$->set_child($2);
                        $$->set_child($3);

                        $$->set_start($1->get_start());
                        $$->set_end($3->get_end());
                    }
                | type_specifier ID                       
                    {
                        parameter.push_back(SymbolInfo(($2->get_name()),$1->get_returnType()));
                        logout << "parameter_list : type_specifier ID\n" ;

                        $$ = new SymbolInfo("parameter_list","type_specifier  ID");
                        $$->set_child($1);
                        $$->set_child($2);

                        $$->set_start($1->get_start());
                        $$->set_end($2->get_end());
                        
                    }
                | type_specifier                          
                    {   
                        parameter.push_back(SymbolInfo("",$1->get_name()));
                        logout<<"parameter_list : type_specifier\n";

                        $$ = new SymbolInfo("parameter_list","type_specifier");
                        $$->set_child($1);

                        $$->set_start($1->get_start());
                        $$->set_end($1->get_end());
                    }
                ;

LCURL_          :   LCURL 
                     {
                        symTable->EnterScope();
                        for(auto i: parameter){

                            int x = symTable->Insert(i.get_name(),i.get_type(),i.get_returnType(),logout);

                            if(!x)errout<<"Line# "<<line_count<<" : Redefinition of parameter '"<<i.get_name()<<"'\n";
                        }

                        $$ = new SymbolInfo("","");
            
                        $$->set_child($1);

                        $$->set_start($1->get_start());
                        $$->set_end($1->get_end());

                     } 
compound_statement : LCURL_
                     statements 
                     RCURL       
                     {
                        
                        logout<<"compound_statement : LCURL statements RCURL\n";  
                        symTable->PrintAll(logout);
                        symTable->ExitScope();

                        $$ = new SymbolInfo("compound_statement","LCURL statements RCURL");
                        vector<SymbolInfo*>* sI = $1->get_child();

                        for(SymbolInfo* info : *sI ){
                            $$->set_child(info);
                        }

                        $$->set_child($2);
                        $$->set_child($3);

                        $$->set_start($1->get_start());
                        $$->set_end($3->get_end());
                                                       
                     }

                    | LCURL_ RCURL                   
                     {
                        
                        logout<<"compound_statement : LCURL RCURL\n";
                        symTable->PrintAll(logout);
                        symTable->ExitScope();

                        $$ = new SymbolInfo("compound_statement","LCURL RCURL");

                        vector<SymbolInfo*>* sI = $1->get_child();
                        for(SymbolInfo* info : *sI ){
                            $$->set_child(info);
                        }

                        $$->set_child($2);

                        $$->set_start($1->get_start());
                        $$->set_end($2->get_end());
                     }
                ;

var_declaration : type_specifier declaration_list SEMICOLON 
                {
                    logout<<"var_declaration : type_specifier declaration_list SEMICOLON\n";
                    
                    
                    for(SymbolInfo info : declaredVar ){
                        if(info.get_type()=="ARRAY"){

                            info.set_returnType($1->get_type());

                        }
                        else{
                            info.set_type($1->get_type());
                        }
                        int x = symTable->Insert(info.get_name(), info.get_type(),info.get_returnType(),logout);
                        SymbolInfo *s = symTable->LookUp(info.get_name());
                        
                    }
                    

                    $$ = new SymbolInfo("var_declaration","type_specifier declaration_list SEMICOLON");

                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());

                }
                ;
type_specifier  : INT       
                {
                    logout<<"type_specifier : INT\n";

                    $$  = new SymbolInfo("type_specifier ","INT");
                    $$->set_returnType("INT");
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | FLOAT     
                {
                    logout<<"type_specifier    : FLOAT\n";
                    $$  = new SymbolInfo("type_specifier","FLOAT");
                    $$->set_returnType("FLOAT");
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | VOID      
                {
                    logout<<"type_specifier     : VOID\n";
                    $$  = new SymbolInfo("type_specifier","VOID");
                    $$->set_returnType("VOID");
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                ;

declaration_list: declaration_list COMMA ID 
                        {
                            logout<<"declaration_list : declaration_list COMMA ID\n";
                           
                          
                            declaredVar.push_back(SymbolInfo($3->get_type(),$3->get_name()));
                            
                            $$  = new SymbolInfo("declaration_list","declaration_list COMMA ID");

                            $$->set_child($1);
                            $$->set_child($2);
                            $$->set_child($3);
                            $$->set_start($1->get_start());
                            $$->set_end($3->get_end());

                            
                        }
                | declaration_list COMMA ID LSQUARE CONST_INT RSQUARE {
                            logout<<"declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD\n";
                            
                            SymbolInfo symInfo = SymbolInfo($3->get_type(),"ARRAY");
                            declaredVar.push_back(symInfo);


                            $3->set_type("ARRAY");

                            $$  = new SymbolInfo("declaration_list","declaration_list COMMA ID LSQUARE CONST_INT RSQUARE");

                            $$->set_child($1);
                            $$->set_child($2);
                            $$->set_child($3);
                            $$->set_child($4);
                            $$->set_child($5);
                            $$->set_child($6);
                            $$->set_start($1->get_start());
                            $$->set_end($6->get_end());
                            
                        }

                | ID{
                            logout<<"declaration_list : ID "<<'\n';

                            declaredVar.push_back(SymbolInfo($1->get_type(),$1->get_name()));
                            
                            $$  = new SymbolInfo("declaration_list","ID");

                            $$->set_child($1);
                            
                            
                            $$->set_start($1->get_start());
                            $$->set_end($1->get_end());

                          
                    }
                | ID LSQUARE  CONST_INT RSQUARE {
                            logout<<"declaration_list : ID LTHIRD CONST_INT RTHIRD\n";

                            
                            SymbolInfo symInfo = SymbolInfo($1->get_type(),"ARRAY");
                            symInfo.set_arraySize(stoi($3->get_type()));
                            declaredVar.push_back(symInfo);
                           

                            $$  = new SymbolInfo("declaration_list","ID LSQUARE CONST_INT RSQUARE");

                            $$->set_child($1);
                            $$->set_child($2);
                            $$->set_child($3);
                            $$->set_child($4);
                           
                            $$->set_start($1->get_start());
                            $$->set_end($4->get_end());
                            
                    }
                ;

statements      : statement             
                  {
                      logout<<"statements : statement\n";
                      $$ = new SymbolInfo("statements","statement");
                      $$->set_child($1);
                      $$->set_start($1->get_start());
                      $$->set_end($1->get_end());
                  }
                | statements statement
                 {
                      logout<<"statements : statements statement\n";
                      $$ = new SymbolInfo("statements","statements statement");
                      
                      $$->set_child($1);
                      $$->set_child($2);
                      
                      $$->set_start($1->get_start());
                      $$->set_end($2->get_end());
                  }
                ;


statement       : var_declaration                                                                    
                  {
                    logout<<"statement : var_declaration\n";

                    $$ = new SymbolInfo("statement","var_declaration");
                      
                    $$->set_child($1);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                  }
                | expression_statement                                                               
                  {
                    logout<<"statement : expression_statement\n";
                    $$ = new SymbolInfo("statement","expression_statement");
                      
                      $$->set_child($1);
                      
                      $$->set_start($1->get_start());
                      $$->set_end($1->get_end());
                  }
                | compound_statement                                                                 
                  {
                    logout<<"statement : compound_statement\n";

                    $$ = new SymbolInfo("statement","compound_statement");
                      
                    $$->set_child($1);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                    
                  }
                | FOR LPAREN expression_statement expression_statement expression RPAREN statement   
                  {
                    logout<<"statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement \n";
                    
                    $$ = new SymbolInfo("statements","FOR LPAREN expression_statement expression_statement expression RPAREN statement");
                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);
                    $$->set_child($5);
                    $$->set_child($6);
                    $$->set_child($7);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($7->get_end()); 
                  }
                | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE                                         
                  {
                    logout<<"statement : IF LPAREN expression RPAREN statement\n";
                    $$ = new SymbolInfo("statement","IF LPAREN expression RPAREN statement");
                      
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);
                    $$->set_child($5);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($5->get_end());
                  }
                | IF LPAREN expression RPAREN statement ELSE statement                               
                  { 
                    logout<<"statement : IF LPAREN expression RPAREN statement ELSE statement\n";
                    $$ = new SymbolInfo("statement","IF LPAREN expression RPAREN statement ELSE statement");

                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);
                    $$->set_child($5);  
                    $$->set_child($6);
                    $$->set_child($7);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($7->get_end());
                  }
                | WHILE LPAREN expression RPAREN statement                                           
                  { 
                    logout<<"statement : WHILE LPAREN expression RPAREN statement\n";
                    $$ = new SymbolInfo("statement","WHILE LPAREN expression RPAREN statement");
                      
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);
                    $$->set_child($5);
                      
                    $$->set_start($1->get_start());
                    $$->set_end($5->get_end());
                  }
                | PRINTLN LPAREN ID RPAREN SEMICOLON                                                 
                  { 
                    logout<<"statement : PRINTLN LPAREN ID RPAREN SEMICOLON\n";
                    $$ = new SymbolInfo("statement","PRINTLN LPAREN ID RPAREN SEMICOLON");
                      
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);
                    $$->set_child($5);
                    
                    $$->set_start($1->get_start());
                    $$->set_end($5->get_end());
                  }
                | RETURN expression SEMICOLON                                                       
                 {
                    logout<<"statement : RETURN expression SEMICOLON\n";
                    
                    $$ = new SymbolInfo("statement","RETURN expression SEMICOLON");
                      
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                 }
                ;

expression_statement: SEMICOLON     
                    {
                        logout<<"expression_statement : SEMICOLON\n";
                         $$ = new SymbolInfo("expression_statement","SEMICOLON");
                      
                        $$->set_child($1);
                        

                        $$->set_start($1->get_start());
                        $$->set_end($1->get_end());
                    }
                    | expression SEMICOLON      
                    {
                        logout<<"expression_statement : expression SEMICOLON\n";
                        $$ = new SymbolInfo("expression_statement","expression SEMICOLON");
                      
                        $$->set_child($1);
                        $$->set_child($2);

                        $$->set_start($1->get_start());
                        $$->set_end($2->get_end());
                    }
                    ;

variable        : ID                            {
                                                    logout<<"variable : ID "<<'\n';
                                                    UndeclaredVariable($1->get_name());

                                                    $$ = new SymbolInfo("variable","ID");
                                                    
                                                    $$->set_child($1);

                                                    $$->set_start($1->get_start());
                                                    $$->set_end($1->get_end());
                                                
                                                }

                | ID LSQUARE expression RSQUARE {
                                                    SymbolInfo *s = NULL;

                                                    s = symTable->LookUp($1->get_name()); 

                                                    
                                                    logout<<"variable : ID LSQUARE expression RSQUARE\n";
                                                    $$ = new SymbolInfo("variable","ID LSQUARE expression RSQUARE");
                                                    
                                                    $$->set_child($1);
                                                    $$->set_child($2);
                                                    $$->set_child($3);
                                                    $$->set_child($4);

                                                    $$->set_start($1->get_start());
                                                    $$->set_end($4->get_end());
                                                }
                ;

expression      : logic_expression                     
                 {
                    logout<<"expression : logic_expression\n";
                    $$ = new SymbolInfo("expression","logic_expression");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                  }
                | variable ASSIGNOP logic_expression   
                 {
                    logout<<"expression : variable ASSIGNOP logic_expression\n";

                    $$ = new SymbolInfo("expression","variable ASSIGNOP logic_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                 }
                ;

logic_expression: rel_expression                        
                 {
                    logout<<"logic_expression : rel_expression\n";
                    $$ = new SymbolInfo("logic_expression","rel_expression");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                 }
                | rel_expression LOGICOP rel_expression
                 {
                    logout<<"logic_expression : rel_expression LOGICOP rel_expression\n";

                    $$ = new SymbolInfo("logic_expression" ,"rel_expression LOGICOP rel_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                 }
                ;

rel_expression  : simple_expression                          
                {
                    logout<<"rel_expression : simple_expression\n";
                    $$ = new SymbolInfo("rel_expression","simple_expression");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | simple_expression RELOP simple_expression  
                {
                    logout<<"rel_expression : simple_expression RELOP simple_expression\n";
                    $$ = new SymbolInfo("rel_expression","simple_expression RELOP simple_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                }
                ;
simple_expression: term                         
                {
                    logout<<"simple_expression : term\n";
                    $$ = new SymbolInfo("simple_expression","term");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | simple_expression ADDOP term  
                {
                    logout<<"simple_expression : simple_expression ADDOP term\n";
                    $$ = new SymbolInfo("simple_expression","simple_expression ADDOP term");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                }
                ;

term            : unary_expression              
                {
                    logout<<"term : unary_expression\n";
                    $$ = new SymbolInfo("term","unary_expression");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | term MULOP unary_expression   
                {
                    logout<<"term : term MULOP unary_expression\n";
                    $$ = new SymbolInfo("term","term MULOP unary_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                }
                ;

unary_expression: ADDOP unary_expression        
                {
                    logout<<"unary_expression : ADDOP unary_expressionn\n";
                    $$ = new SymbolInfo("unary_expression","ADDOP unary_expressionn");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);

                    $$->set_start($1->get_start());
                    $$->set_end($2->get_end());
                }
                | NOT unary_expression          
                { 
                    logout<<"unary_expression : NOT unary_expression\n";
                    $$ = new SymbolInfo("unary_expression","NOT unary_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);

                    $$->set_start($1->get_start());
                    $$->set_end($2->get_end());
                }
                | factor                        
                { 
                    logout<<"unary_expression : factor\n";
                    $$ = new SymbolInfo("unary_expression","factor");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                ;

factor          : variable              
                {
                   logout<<"factor : variable\n";     
                   $$ = new SymbolInfo("factor" ,"variable ");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());           
                }

                | ID LPAREN argument_list RPAREN 
                {
                    logout<<"factor : ID LPAREN argument_list RPAREN \n";
                    SymbolInfo *s = symTable->LookUp($1->get_name());  
                                                    
                    if(s==NULL){
                        errout<<"Line# "<<line_count<<" : "<<"Undeclared function "<<($1->get_name())<< "\n";
                    } 


                    $$ = new SymbolInfo("factor","ID LPAREN argument_list RPAREN");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);
                    $$->set_child($4);

                    $$->set_start($1->get_start());
                    $$->set_end($4->get_end());
                }

                | LPAREN expression RPAREN       
                {
                    logout<<"factor : LPAREN expression RPAREN\n";
                    $$ = new SymbolInfo("factor","LPAREN expression RPAREN");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                }
                | CONST_INT                      
                {
                    logout<<"factor : CONST_INT \n";
                    $$ = new SymbolInfo("factor","CONST_INT");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | CONST_FLOAT                    
                {
                    logout<<"factor : CONST_FLOAT \n";
                    $$ = new SymbolInfo("factor","CONST_FLOAT");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                | variable INCOP                 
                {
                    logout<<"factor : variable INCOP\n";
                    $$ = new SymbolInfo("factor","variable INCOP");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($2->get_end());
                }
                | variable DECOP                 
                {
                    logout<<"factor : variable DECOP\n";
                    $$ = new SymbolInfo("factor","variable DECOP");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);

                    $$->set_start($1->get_start());
                    $$->set_end($2->get_end());
                }
                ;

argument_list   : arguments 
                {
                    logout<<"argument_list : arguments\n";
                    $$ = new SymbolInfo("argument_list","arguments");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                }
                |  { $$ = new SymbolInfo("argument_list ","",line_count);}
                ;

arguments       : arguments COMMA logic_expression
                  {
                    logout<<"arguments : arguments COMMA logic_expression\n";

                    $$ = new SymbolInfo("arguments","arguments COMMA logic_expression");
                                                    
                    $$->set_child($1);
                    $$->set_child($2);
                    $$->set_child($3);

                    $$->set_start($1->get_start());
                    $$->set_end($3->get_end());
                  }
                | logic_expression 
                  { 
                    logout<<"arguments : logic_expression\n";

                    $$ = new SymbolInfo("arguments","logic_expression");
                                                    
                    $$->set_child($1);

                    $$->set_start($1->get_start());
                    $$->set_end($1->get_end());
                  }
                ;
%%

int main(int argc,char *argv[]){
	FILE *fp;

	if((fp=fopen(argv[1],"r"))==NULL){
		printf("Cannot Open Input File.\n");
		exit(1);
	}

	logout.open("log.txt");
	errout.open("error.txt");
    parsetree.open("parse.txt");

	yyin=fp;
	yyparse();


	logout<<"Total lines: "<<line_count<<endl;
    logout<<"Total errors: "<<error<<endl;

	fclose(yyin);
 	logout.close();
	errout.close();
    parsetree.close();
	return 0;
}
