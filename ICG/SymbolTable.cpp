
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cmath>


using namespace std;


class SymbolInfo {

private:
    string name;
    string type;
    SymbolInfo* prev;
    SymbolInfo* next;

    int startLine;
    int endLine;
    int offset;
    string dataType;
    int infoType;
    int arraySize;
    vector<SymbolInfo*>* parameters;
    vector<SymbolInfo*>* childList;


public:

    static const int VARIABLE = 1;
    static const int FUNCTION_DECLARATION = 2;
    static const int FUNCTION_DEFINITION = 3;

    SymbolInfo() {
        this->name = "";
        this->type = "";
        this->dataType = "";
        prev = NULL;
        next = NULL;
        this->infoType = VARIABLE;
        this->arraySize = -1;
        this->parameters = new vector<SymbolInfo*>();
        this->startLine = 0;
        this->endLine = 0;
        childList = new vector<SymbolInfo*>();
        offset = 0;
    }
    SymbolInfo(SymbolInfo* symbol) {
        this->name = symbol->name;
        this->type = symbol->type;
        this->dataType = symbol->dataType;
        this->prev = symbol->prev;
        this->next = symbol->next;
        this->arraySize = symbol->arraySize;
        this->infoType = symbol->infoType;
        this->parameters = symbol->parameters;
        this->startLine = 0;
        this->endLine = 0;
        childList = new vector<SymbolInfo*>();
        offset = 0;
    }
    SymbolInfo(string name, string type) {
        this->name = name;
        this->type = type;
        this->dataType = "";
        prev = NULL;
        next = NULL;
        this->infoType = VARIABLE;
        this->arraySize = -1;
        this->parameters = new vector<SymbolInfo*>();
        this->startLine = 0;
        this->endLine = 0;
        childList = new vector<SymbolInfo*>();
        offset = 0;
    }
    SymbolInfo(string name, string type, string dataType, int infoType = VARIABLE, int arraySize = -1) {
        this->name = name;
        this->type = type;
        this->next = nullptr;
        this->dataType = dataType;
        this->infoType = infoType;
        this->arraySize = arraySize;
        this->startLine = 0;
        this->endLine = 0;
        this->parameters = new vector<SymbolInfo*>();
        childList = new vector<SymbolInfo*>();
        offset = 0;
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

    void setStartLine(int line) {
        this->startLine = line;
    }
    int getStartLine() {
        return startLine;
    }
    void setEndLine(int line) {
        this->endLine = line;
    }
    int getEndLine() {
        return endLine;
    }

    void addChild(SymbolInfo* child) {
        childList->push_back(child);
    }
    SymbolInfo* getChild(int pos) {
        return (*childList)[pos];
    }
    vector<SymbolInfo*>* getChildList() {
        return childList;
    }

    void setReturnType(string dataType) {
        this->dataType = dataType;
    }

    string getReturnType() {
        return dataType;
    }

    void setDataType(string dataType) {
        this->dataType = dataType;
    }
    string getDataType() {
        return dataType;
    }

    void setInfoType(int infoType) {
        this->infoType = infoType;
    }

    int getInfoType() {
        return infoType;
    }

    bool isArray() {
        return (arraySize != -1);
    }

    void setArraySize(int arraySize) {
        this->arraySize = arraySize;
    }

    int getArraySize() {
        return arraySize;
    }

    bool isFunction() {
        return (infoType == FUNCTION_DECLARATION or infoType == FUNCTION_DEFINITION);
    }

    void setOffset(int offset) {
        this->offset = offset;
    }
    int getOffset() {
        return offset;
    }

    void setParameters(vector<SymbolInfo*>* parameters) {
        for (SymbolInfo* param : *parameters) {
            this->parameters->push_back(param);
        }
    }
    vector<SymbolInfo*>* getParameters() {
        return parameters;
    }

    void printChild(int depth, ofstream& parseout){
    for(int i = 0; i < depth; i++) {
        parseout << " ";
    }
    if(childList->size() == 0) {
        parseout << type << " : " << name << "\t" << "<Line: " << startLine << ">\n";
    }
    else {
        parseout << name << " : " << type << "\t" << "<Line: " << startLine << "-" << endLine << ">\n";
        
        for(SymbolInfo *symbol : *childList){
                symbol->printChild(depth+1, parseout);
        }
    }
    
}

};


class ScopeTable {
private:
    SymbolInfo* table;
    ScopeTable* parent_scope;
    int number;
    int bucket;

    long long SDBMHash(string str, int bucket) {
        long long hash = 0;
        int i = 0;
        int len = str.length();

        for (i = 0; i < len; i++) {
            hash = ((str[i]%bucket) + ((hash << 6)%bucket) + ((hash << 16)%bucket) - hash) % bucket;
        }

        return hash%bucket;
    }

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
    void print(ofstream& logout) {
        logout << "\tScopeTable# " << number << endl;
        SymbolInfo* temp = table;
        for (int i = 0; i < bucket; i++) {
            temp = table+i;
            if (temp->getNext() == NULL) {
                continue;
            }
			logout << "\t" << i+1 << "--> ";
            while(temp->getNext() != NULL) {
                temp = temp->getNext();
				logout << "<" << temp->getName() <<  "," << temp->getType()<< "> ";
            }
            logout << endl;
			
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

    long long SDBMHash(string str, int bucket) {
        long long hash = 0;
        int i = 0;
        int len = str.length();

        for (i = 0; i < len; i++) {
            hash = ((str[i]%bucket) + ((hash << 6)%bucket) + ((hash << 16)%bucket) - hash) % bucket;
        }

        return hash%bucket;
    }

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
    void printCurr(ofstream& logout) {
        currentScope->print(logout);
    }
    void printAll(ofstream& logout) {
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
