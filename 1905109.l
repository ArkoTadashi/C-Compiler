%option noyywrap

%{
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <cstring>

using namespace std;

int line_count = 1;
int err_count = 0;


FILE *logout;
FILE *tokenout;

long long SDBMHash(string str, int bucket) {
	long long hash = 0;
	int i = 0;
	int len = str.length();

	for (i = 0; i < len; i++) {
		hash = ((str[i]%bucket) + ((hash << 6)%bucket) + ((hash << 16)%bucket) - hash) % bucket;
	}

	return hash%bucket;
}



class SymbolInfo {

private:
    string name;
    string type;
    SymbolInfo* prev;
    SymbolInfo* next;

public:
    SymbolInfo() {
        prev = NULL;
        next = NULL;
    }
    SymbolInfo(string name, string type) {
        this->name = name;
        this->type = type;
        prev = NULL;
        next = NULL;
    }

    void setName(string name) {
        this->name = name;
    }
    string getName() {
        return name;
    }
    void setType(string type) {
        this->type = type;
    }
    string getType() {
        return type;
    }
    void setPrev(SymbolInfo* prev) {
        this->prev = prev;
    }
    SymbolInfo* getPrev() {
        return prev;
    }
    void setNext(SymbolInfo* next) {
        this->next = next;
    }
    SymbolInfo* getNext() {
        return next;
    }

};


class ScopeTable {
private:
    SymbolInfo* table;
    ScopeTable* parent_scope;
    int number;
    int bucket;

public:
    ScopeTable(ScopeTable* parent_scope = NULL, int number = 0, int bucket = 1) {
        this->parent_scope = parent_scope;
        this->bucket = bucket;
        this->number = number;
        table = new SymbolInfo[bucket];
    }
    ~ScopeTable() {
        delete[] table;
    }


    void setParent(ScopeTable* parent_scope) {
        this->parent_scope = parent_scope;
    }
    ScopeTable* getParent() {
        return parent_scope;
    }

    bool insert(string symbol, string type) {
        if (look_up(symbol, false) != NULL) {
            return false;
        }
        int hash = SDBMHash(symbol, bucket);
        SymbolInfo* temp = table+hash;
        SymbolInfo* temp2 = new SymbolInfo(symbol, type);
        int cnt = 0;
        while (temp->getNext() != NULL) {
            cnt++;
            temp = temp->getNext();
        }
        temp->setNext(temp2);
        temp2->setPrev(temp);
        return true;
    }
    SymbolInfo* look_up(string symbol, bool pp) {
        int hash = SDBMHash(symbol, bucket);
        SymbolInfo* temp = table+hash;
        int cnt = 0;
        while (temp->getNext() != NULL) {
            temp = temp->getNext();
            cnt++;
            if (temp->getName() == symbol) {
                return temp;
            }
        }
        return NULL;
    }
    bool remove(string symbol) {
        if (look_up(symbol, false) == NULL) {
            return false;
        }
        int hash = SDBMHash(symbol, bucket);
        SymbolInfo* temp = table+hash;
        int cnt = 0;
        while (temp->getNext() != NULL) {
            cnt++;
            temp = temp->getNext();
            if (temp->getName() == symbol) {
                SymbolInfo* temp2 = temp->getPrev();
                temp2->setNext(temp->getNext());
                if (temp->getNext() != NULL) {
                    temp2 = temp->getNext();
                    temp2->setPrev(temp->getPrev());
                }
                delete temp;
                break;
            }
        }
        return true;
    }
    void print(FILE* logout) {
        fprintf(logout,"\tScopeTable# %d\n",number);
        SymbolInfo* temp = table;
        for (int i = 0; i < bucket; i++) {
            temp = table+i;
            if (temp->getNext() == NULL) {
                continue;
            }
			fprintf(logout, "\t%d--> ", i+1);
            while(temp->getNext() != NULL) {
                temp = temp->getNext();
				fprintf(logout, "<%s,%s> ", temp->getName().c_str(), temp->getType().c_str());
            }
            fprintf(logout, "\n");
			
        }
    }
    void setNumber(int number) {
        this->number = number;
    }
    int getNumber() {
        return number;
    }
};





class SymbolTable {
private:
    ScopeTable* currentScope;
    int bucket;
    int num;

public:
    SymbolTable(int bucket = 1) {
        this->bucket = bucket;
        currentScope = NULL;
        num = 0;
        newScope();
    }
    ~SymbolTable() {
        ScopeTable* temp = currentScope;
        while (temp != NULL) {
            currentScope = currentScope->getParent();
            delete temp;
            temp = currentScope;
        }
    }

    void newScope() {
        num++;
        ScopeTable* temp = new ScopeTable(currentScope, num, bucket);
        currentScope = temp;
    }
    bool closeScope() {
        if (currentScope->getParent() == NULL) {
            return false;
        }
        ScopeTable* temp = currentScope;
        currentScope = currentScope->getParent();
        delete temp;
        return true;
    }
    bool insert(string symbol, string type) {
        return currentScope->insert(symbol, type);
    }
    bool remove(string symbol) {
        return currentScope->remove(symbol);
    }
    SymbolInfo* look_up(string symbol) {
        ScopeTable* tempScope = currentScope;
        while(1) {
            SymbolInfo* temp = tempScope->look_up(symbol, false);
            if (temp != NULL) {
                return tempScope->look_up(symbol, true);
            }

            if (tempScope->getParent() == NULL) {
                break;
            }
            tempScope = tempScope->getParent();
        }
        return tempScope->look_up(symbol, true);
        return NULL;
    }
    void printCurr(FILE* logout) {
        currentScope->print(logout);
    }
    void printAll(FILE* logout) {
        ScopeTable* tempScope = currentScope;
        while (tempScope != NULL) {
            tempScope->print(logout);
            tempScope = tempScope->getParent();
        }
    }
    int getNum() {
        return currentScope->getNumber();
    }


};

SymbolTable st(109);

%}

WHITESPACE [ \t\f\r\v]+
NEWLINE [\r]?\n


NONEWLINE [^\r\n]
ALL ({NONEWLINE}|{NEWLINE})
NOSTAR [^\*]
NOSTRING [^"\\\r\n]

UNFINISHEDSTRING \"({NOSTRING}|(\\{WHITESPACE}*{ALL}))*
STRING {UNFINISHEDSTRING}\"

SLASHCOMMENT "//"({NONEWLINE}*(\\{NEWLINE})?{NONEWLINE}*)*

UNFINISHEDSTARCOMMENT ("/*")({NOSTAR}|([\*]+[^*/]))*
STARCOMMENT {UNFINISHEDSTARCOMMENT}[\*]*("*/")


LETTER [a-zA-Z]
DIGIT [0-9]
DIGITS {DIGIT}+
FLOAT {DIGITS}?(\.{DIGITS})?([Ee][+-]?{DIGITS})?

TOOMANYPOINT {DIGITS}?(((\.)+({DIGITS})?)*)?([Ee][+-]?{DIGITS})?(((\.)+({DIGITS})?)*)?
ILLEGAL {DIGITS}?(\.{DIGITS})?([Ee][+-]?{FLOAT})?

SPECIAL ("\\'"|"\\\""|"\\n"|"\\t"|"\\\\"|"\\a"|"\\f"|"\\r"|"\\b"|"\\v"|"\\0")
NOQUOTESLASH [^\\'(\r\n);]
CHR ({SPECIAL}|{NOQUOTESLASH})
CHARACTER '{CHR}'
UNFINISHEDCHAR ('({CHR})*)|('\\')
MULTICHAR '({CHR})({CHR})+'
EMPTYCHAR ''
UNRECOGNISEDCHAR ('("\\"[^{SPECIAL}]?)'|{NONEWLINE})


INCOP ("++"|"--")
ADDOP ("+"|"-")
MULOP ("*"|"/"|"%")
RELOP ("<"|"<="|">"|">="|"=="|"!=")
LOGICOP ("&&"|"||")
BITOP ("&"|"|"|"^"|"<<"|">>")

ID [a-zA-Z_][a-zA-Z0-9_]*

INVALID ({FLOAT}{ID})



%%

{NEWLINE} {line_count++;}

{WHITESPACE} {}

{SLASHCOMMENT} {
    fprintf(logout,"Line# %d: Token <SINGLE LINE COMMENT> Lexeme %s found\n",line_count,yytext);
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
}

{STARCOMMENT} {
    fprintf(logout,"Line# %d: Token <MULTI LINE COMMENT> Lexeme %s found\n",line_count,yytext);
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
}  

{UNFINISHEDSTARCOMMENT} {
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
    fprintf(logout,"Error at line# %d: UNFINISHED_COMMENT %s\n",line_count,yytext);
	err_count++;
}




{DIGITS} {
	fprintf(tokenout,"<CONST_INT, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <CONST_INT> Lexeme %s found\n",line_count,yytext);
}

{FLOAT} {
    fprintf(tokenout,"<CONST_FLOAT, %s>\n",yytext);
    fprintf(logout,"Line# %d: Token <CONST_FLOAT> Lexeme %s found\n",line_count,yytext);
}

{ILLEGAL} {
	fprintf(logout,"Error at line# %d: ILLFORMED_NUMBER %s\n",line_count,yytext);
	err_count++;
}

{TOOMANYPOINT} {
	fprintf(logout,"Error at line# %d: TOO_MANY_DECIMAL_POINTS %s\n",line_count,yytext);
	err_count++;
}

{EMPTYCHAR} {
	fprintf(logout,"Error at line# %d: EMPTY_CONST_CHAR %s\n",line_count,yytext);
	err_count++;
}

{CHARACTER} {
    int off = 1;
    for (int i = 0; ; i++) {
        if (yytext[i+off] == '\0') {
            yytext[i-1] = '\0';
            break;
        }
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'n') {
			yytext[i] = '\n';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\\') {
			yytext[i] = '\\';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\'') {
			yytext[i] = '\'';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\"') {
			yytext[i] = '\"';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 't') {
			yytext[i] = '\t';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'a') {
			yytext[i] = '\a';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'f') {
			yytext[i] = '\f';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'b') {
			yytext[i] = '\b';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'v') {
			yytext[i] = '\v';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'r') {
			yytext[i] = '\r';
			off++;
		}
		else {
			yytext[i] = yytext[i+off];
		}
    }
	fprintf(tokenout,"<CONST_CHAR, %s>\n",yytext);
    fprintf(logout,"Line# %d: Token <CONST_CHAR> Lexeme %s found\n",line_count,yytext);
}

{MULTICHAR} {
	fprintf(logout,"Error at line# %d: MULTICHAR_CONST_CHAR %s\n",line_count,yytext);
	err_count++;
}

{UNFINISHEDCHAR} {
	fprintf(logout,"Error at line# %d: UNFINISHED_CONST_CHAR %s\n",line_count,yytext);
	err_count++;
}





{STRING} {
	bool multi = false;
	int linee = line_count;
	int off = 1;
	int off2 = 0;
    char text[strlen(yytext)];
    strcpy(text, yytext);
	for (int i = 0; ; i++) {
		if (yytext[i+off] == '\0') {
            yytext[i-off2-1] = '\0';
            break;
        }
        if (yytext[i+off] == '\\' and yytext[i+off+1] == '\r' and yytext[i+off+2] == '\n') {
            multi = true;
			line_count++;
			off += 2;
            off2++;
        }
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\n') {
            multi = true;
			line_count++;
			off++;
            off2++;
        }
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'n') {
			yytext[i-off2] = '\n';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\\') {
			yytext[i-off2] = '\\';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\'') {
			yytext[i-off2] = '\'';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == '\"') {
			yytext[i-off2] = '\"';
			off++;
		}
		else if (yytext[i+off] == '\\' and yytext[i+off+1] == 't') {
			yytext[i-off2] = '\t';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'a') {
			yytext[i-off2] = '\a';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'f') {
			yytext[i-off2] = '\f';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'b') {
			yytext[i-off2] = '\b';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'v') {
			yytext[i-off2] = '\v';
			off++;
		}
        else if (yytext[i+off] == '\\' and yytext[i+off+1] == 'r') {
			yytext[i-off2] = '\r';
			off++;
		}
		else {
			yytext[i-off2] = yytext[i+off];
		}
	}
	if (multi) {
		fprintf(tokenout,"<MULTI LINE STRING, %s>\n", yytext);
		fprintf(logout,"Line# %d: Token <MULTI LINE STRING> Lexeme %s found\n",linee,text);
	}
    else {
		fprintf(tokenout,"<SINGLE LINE STRING, %s>\n", yytext);
		fprintf(logout,"Line# %d: Token <SINGLE LINE STRING> Lexeme %s found\n",linee,text);
	}
}

{UNFINISHEDSTRING} {
	for (int i = 0; yytext[i] != '\0'; i++) {
		if (yytext[i] == '\n') {
			line_count++;
		}
	}
    fprintf(logout,"Error at line# %d: UNFINISHED_STRING %s\n",line_count,yytext);
	err_count++;
}


"if" {
	fprintf(tokenout,"<IF, if>\n");
	fprintf(logout,"Line# %d: Token <IF> Lexeme %s found\n",line_count,yytext);
}
		
"else" {
	fprintf(tokenout,"<ELSE, else>\n");
	fprintf(logout,"Line# %d: Token <ELSE> Lexeme %s found\n",line_count,yytext);
}

"for" {
	fprintf(tokenout,"<FOR, for>\n");
	fprintf(logout,"Line# %d: Token <FOR> Lexeme %s found\n",line_count,yytext);
}

"do" {
	fprintf(tokenout,"<DO, do>\n");
	fprintf(logout,"Line# %d: Token <DO> Lexeme %s found\n",line_count,yytext);
}

"int" {
	fprintf(tokenout,"<INT, int>\n");
	fprintf(logout,"Line# %d: Token <INT> Lexeme %s found\n",line_count,yytext);
}

"float" {
	fprintf(tokenout,"<FLOAT, float>\n");
	fprintf(logout,"Line# %d: Token <FLOAT> Lexeme %s found\n",line_count,yytext);
}

"void" {
	fprintf(tokenout,"<VOID, void>\n");
	fprintf(logout,"Line# %d: Token <VOID> Lexeme %s found\n",line_count,yytext);
}

"switch" {
    fprintf(tokenout,"<SWITCH, switch>\n");
    fprintf(logout,"Line# %d: Token <SWITCH> Lexeme %s found\n",line_count,yytext);
}

"default" {
	fprintf(tokenout,"<DEFAULT, default>\n");
	fprintf(logout,"Line# %d: Token <DEFAULT> Lexeme %s found\n",line_count,yytext);
}

"while" {
	fprintf(tokenout,"<WHILE, while>\n");
	fprintf(logout,"Line# %d: Token <WHILE> Lexeme %s found\n",line_count,yytext);
}

"break" {
	fprintf(tokenout,"<BREAK, break>");
	fprintf(logout,"Line# %d: Token <BREAK> Lexeme %s found\n",line_count,yytext);
}

"char" {
	fprintf(tokenout,"<CHAR, char>\n");
	fprintf(logout,"Line# %d: Token <CHAR> Lexeme %s found\n",line_count,yytext);
}

"double" {
    fprintf(tokenout,"<DOUBLE, double>\n");
    fprintf(logout,"Line# %d: Token <DOUBLE> Lexeme %s found\n",line_count,yytext);
}

"return" {
    fprintf(tokenout,"<RETURN, return>\n");
    fprintf(logout,"Line# %d: Token <RETURN> Lexeme %s found\n",line_count,yytext);
}

"case" {
	fprintf(tokenout,"<CASE, case>\n");
	fprintf(logout,"Line# %d: Token <CASE> Lexeme %s found\n",line_count,yytext);
}

"continue" {
    fprintf(tokenout,"<CONTINUE, continue>\n");
    fprintf(logout,"Line# %d: Token <CONTINUE> Lexeme %s found\n",line_count,yytext);
}

{INCOP} {
	fprintf(tokenout,"<INCOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <INCOP> Lexeme %s found\n",line_count,yytext);
}

{ADDOP} {
	fprintf(tokenout,"<ADDOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <ADDOP> Lexeme %s found\n",line_count,yytext);
}

{MULOP} {
	fprintf(tokenout,"<MULOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <MULOP> Lexeme %s found\n",line_count,yytext);
}

{RELOP} {
	fprintf(tokenout,"<RELOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <RELOP> Lexeme %s found\n",line_count,yytext);
}

"=" {
	fprintf(tokenout,"<ASSIGNOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <ASSIGNOP> Lexeme %s found\n",line_count,yytext);
}

{LOGICOP} {
    fprintf(tokenout,"<LOGICOP, %s>\n",yytext);
    fprintf(logout,"Line# %d: Token <LOGICOP> Lexeme %s found\n",line_count,yytext);
}

{BITOP}	{
	fprintf(tokenout,"<BITOP, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <BITOP> Lexeme %s found\n",line_count,yytext);
}

"!" {
    fprintf(tokenout,"<NOT, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <NOT> Lexeme %s found\n",line_count,yytext);
}

"(" {
    fprintf(tokenout,"<LPAREN, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <LPAREN> Lexeme %s found\n",line_count,yytext);
}

")" {
    fprintf(tokenout,"<RPAREN, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <RPAREN> Lexeme %s found\n",line_count,yytext);
}

"{" {
	st.newScope();
    fprintf(tokenout,"<LCURL, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <LCURL> Lexeme %s found\n",line_count,yytext);
}
		
"}" {
	st.closeScope();
    fprintf(tokenout,"<RCURL, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <RCURL> Lexeme %s found\n",line_count,yytext);
}

"[" {
    fprintf(tokenout,"<LSQUARE, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <LSQUARE> Lexeme %s found\n",line_count,yytext);
}

"]" {
    fprintf(tokenout,"<RSQUARE, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <RSQUARE> Lexeme %s found\n",line_count,yytext);
}

"," {
    fprintf(tokenout,"<COMMA, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <COMMA> Lexeme %s found\n",line_count,yytext);
}

";" {
    fprintf(tokenout,"<SEMICOLON, %s>\n",yytext);
	fprintf(logout,"Line# %d: Token <SEMICOLON> Lexeme %s found\n",line_count,yytext);
}



{ID} {
    fprintf(tokenout,"<ID, %s>\n",yytext);
    fprintf(logout,"Line# %d: Token <ID> Lexeme %s found\n",line_count,yytext);
    if(!st.insert(yytext, "ID")) {
        fprintf(logout,"\t%s already exisits in the current ScopeTable\n",yytext);
    }
    else {
        st.printAll(logout);
    }
	
}

{INVALID} {
	fprintf(logout,"Error at line# %d: INVALID_ID_SUFFIX_NUM_PREFIX %s\n",line_count,yytext);
	err_count++;
}


{UNRECOGNISEDCHAR} {
	fprintf(logout,"Error at line# %d: UNRECOGNIZED_CHAR %s\n",line_count,yytext);
	err_count++;
}


			

%%

int main(int argc, char** argv) {
	if (argc != 2){
		printf("Please provide input file name and try again\n");
		return 0;
	}
	
	FILE *fin=fopen(argv[1],"r");
	if (fin == NULL){
		printf("Cannot open specified file\n");
		return 0;
	}
	
	logout = fopen("1905109_log.txt","w");
	tokenout = fopen("1905109_token.txt","w");

	yyin = fin;
	yylex();
	st.printAll(logout);
    fprintf(logout, "Total lines: %d\nTotal errors: %d", line_count, err_count);
	fclose(yyin);
	fclose(tokenout);
	fclose(logout);
	return 0;
}
