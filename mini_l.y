%{
#define YY_NO_UNPUT
#include <stdio.h>
#include <string>
#include <cstring>
#include <vector>
#include <set>
#include <stdlib.h>
#include <stdbool.h>
#include "y.tab.h"
#include "t.tab.h"
#include "heading.h"

using namespace std;

void yyerror(const char* s);
int yylex(void);


extern int currLine;
extern int currPos;
extern char* yytext;
extern char* programName;
  
int labelCount = 0;
int tempCount = 0;
int paramCount = 0;

string new_label(){
  string x = "__label__";
  x += to_string(labelCount);
  labelCount += 1;
  return x;
}

string new_temp(){
  string x = "__temp__";
  x += to_string(tempCount);
  tempCount += 1;
  return x;
}

bool isReserved = false;

set<string> functionSet;
set<string> variableSet;
string errors;
vector<string> reservedWords = {"FUNCTION", "BEGIN_PARAMS", "END_PARAMS", "BEGIN_LOCALS", "END_LOCALS", "BEGIN_BODY", "END_BODY", "INTEGER",
    "ARRAY", "OF", "IF", "THEN", "ENDIF", "ELSE", "WHILE", "DO", "FOREACH", "IN", "BEGINLOOP", "ENDLOOP", "CONTINUE", "READ", "WRITE", "AND", "OR", 
    "NOT", "TRUE", "FALSE", "RETURN", "SUB", "ADD", "MULT", "DIV", "MOD", "EQ", "NEQ", "LT", "GT", "LTE", "GTE", "L_PAREN", "R_PAREN", "L_SQUARE_BRACKET",
    "R_SQUARE_BRACKET", "COLON", "SEMICOLON", "COMMA", "ASSIGN", "function", "Ident", "beginparams", "endparams", "beginlocals", "endlocals", "integer", 
    "beginbody", "endbody", "beginloop", "endloop", "if", "endif", "foreach", "continue", "while", "else", "read", "do", "write"};

%}

%union{
  int int_val;
  char*	op_val;
  
  struct statement_semval {
	 char *code;
	 char *result_id;
	 char *label;
	 char *arr_size;
	 char *arr_name;
	 bool is_array;
  } s;

  struct expression_semval {
	 char *code;
	 char *result_id;
	 char *arr_size;
	 char *arr_name;
	 bool is_array;
  } e;

  struct comp_semval {
	 char *optr;
  } c;

}

%start prog_start
%token FUNCTION BEGIN_PARAMS END_PARAMS BEGIN_LOCALS END_LOCALS BEGIN_BODY END_BODY INTEGER ARRAY OF IF THEN ENDIF ELSE FOR WHILE DO BEGINLOOP ENDLOOP CONTINUE READ WRITE AND OR NOT TRUE FALSE RETURN
%token SUB ADD MULT DIV MOD EQ NEQ LT GT LTE GTE SEMICOLON COLON COMMA L_PAREN R_PAREN L_SQUARE_BRACKET R_SQUARE_BRACKET ASSIGN
%token <int_val> NUMBER
%token <op_val> IDENT

%type <s> prog_start progInner function funcInnerLocals funcInnerTwo funcInnerParams statement stateInnerOne stateInnerTwo
%type <e> bool_expr var addFunc ident termInnerOne expression multiplicative_expr term declaration decInner relation_expr relation_and_expr
%type <c> comp
%%

prog_start:     progInner {
                  for (auto it=variableSet.begin(); it != variableSet.end(); ++it) 
                    cout << ' ' << *it; 
                    cout << endl;

                  // Check if function main is declared (test 03)
                  if (functionSet.count("main") == 0) {
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": function main not declared\n";
                    errors += errormessage;
                  }

                  // Check if variable name is same as program name (test 04)
                  // cout << programName << endl;
                  if (variableSet.count(programName) != 0) {
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": declared program name as variable\n";
                    errors += errormessage;
                  }

                  // Check if any errors --> end program and output errors if so
                  if (errors.size() != 0) {
                    cout << errors;
                    exit(1);
                  } else {
                    cout << $1.code;
                  }
                }
                ;
progInner:      function progInner {
                  ostringstream oss;
                  oss << $1.code << $2.code;
                  $$.code = strdup(oss.str().c_str());
                }
                | {
                  $$.code = "";
                }
                ;
function:       FUNCTION addFunc SEMICOLON BEGIN_PARAMS funcInnerParams END_PARAMS BEGIN_LOCALS funcInnerLocals END_LOCALS BEGIN_BODY funcInnerTwo END_BODY 
                {
                  ostringstream oss;
                  string temp = $2.result_id;
                  
                  oss << "func " << $2.result_id << endl;
                  oss << $5.code << $8.code;

                  string findContinue($11.code);

                  // Check for any leftover continues (test 09)
                  if (findContinue.find("continue") != std::string::npos) {
                    string temp = $2.result_id;
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": continue outside loop in function " + temp+ "\n";
                    errors += errormessage;
                  }
                  oss << $11.code;

                  $$.code = strdup(oss.str().c_str());
                }
                ;
addFunc:      ident {
                // Add func name to function set
                functionSet.insert($1.result_id);
                  
                $$.result_id = $1.result_id;
              }

ident:          IDENT
                {
				          $$.code = "";
                  $$.result_id = $1;
                }
                ;
funcInnerParams:    declaration SEMICOLON funcInnerParams
                    {
                      ostringstream oss;
                      oss << $1.code;
                      oss << "= " << $1.result_id << ", $" << paramCount << endl;
                      $$.code = strdup(oss.str().c_str());
                      paramCount++;
                    }
                    |
                    {
                      $$.code = "";
                      $$.result_id = "";
                    }
                    ;
funcInnerLocals:    declaration SEMICOLON funcInnerLocals 
                    {
                      ostringstream oss;
                      oss << $1.code;
                      oss << $3.code;
                      $$.code = strdup(oss.str().c_str());
                      
                    }
                    | 
                    {
                      $$.code = "";
                      $$.result_id = "";
                    }
                    ;
funcInnerTwo:   statement SEMICOLON funcInnerTwo 
                {
				  ostringstream oss;
				  oss << $1.code << $3.code;
                  $$.code = strdup(oss.str().c_str());
                }
                | 
                {
				  ostringstream oss;
				  oss << "endfunc" << endl << endl;
				  $$.code = strdup(oss.str().c_str());
                }
                ;
declaration:    decInner COLON INTEGER
                {
                  if (strchr($1.result_id, '#') == NULL){
                    ostringstream oss;
                    oss << ". " << $1.result_id << endl;
                    $$.code = strdup(oss.str().c_str());
                    $$.result_id = $1.result_id;
                  }
                  else {
                    char curr = $1.result_id[0];
                    int count = 0;
                    ostringstream oss;
                    while (count < strlen($1.result_id)){
                    ostringstream lss;
                    curr = $1.result_id[count];

                    while ((curr != '#') && count < strlen($1.result_id)){
                      lss << curr;
                      count += 1;
                      curr = $1.result_id[count];
                    }
                    oss << ". " << lss.str().c_str() << endl;
                    count += 1;
                  }

                  // Check for declaration of a reserved word (test 05)
                  // string errormessage = "";
                  // string temp = $1.result_id;
                  // for (unsigned int i = 0; i < reservedWords.size(); ++i) {
                  //   if (reservedWords.at(i) == temp) {
                  //     string errormessage;
                  //     errormessage = "ERROR on line " + to_string(currLine) + ": invalid declaration of reserved word " + temp + "\n";
                  //     errors += errormessage;

                  //     isReserved = true;
                  //   }
                  // } 

                  // if (variableSet.count(temp) != 0) {
                  //   string errormessage;
                  //   errormessage = "ERROR on line " +  to_string(currLine) + ": redeclaration of variable " + temp + "\n";
                  //   errors += errormessage;
                  // }
                  // else if (isReserved){
                  //   string errormessage;
                  //   errormessage = "ERROR on line " + to_string(currLine) + ": invalid declaration of reserved word " + temp + "\n";
                  //   errors += errormessage;
                  // }
                  // else {
                  //   variableSet.insert(temp);
                  // }

                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = $1.result_id;
                  }
                }
                | decInner COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER 
                {
                  
                  // Check if declaring arrays of size <= 0 (test 08)
                   if ($5 <= 0) {
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": array size can't be less than 1\n";
                    errors += errormessage;
                  }

                  ostringstream oss;
                  oss << ".[] " << $1.result_id << ", " << $5 << endl;

                  // string temp = $1.result_id;
                  // if (variableSet.count(temp) != 0) {
                  //   string errormessage;
                  //   errormessage = "ERROR on line " +  to_string(currLine) + ": redeclaration of variable " + temp + "\n";
                  //   errors += errormessage;
                  // }
                  // else if (isReserved){
                  //   string errormessage;
                  //   errormessage = "ERROR on line " + to_string(currLine) + ": invalid declaration of reserved word " + temp + "\n";
                  //   errors += errormessage;
                  // }
                  // else {
                  //   variableSet.insert(temp);
                  // }

                  $$.arr_size = strdup(to_string($5).c_str());
                  $$.code = strdup(oss.str().c_str());
                }
                ;
decInner:       ident 
                {
                  string temp = $1.result_id;
                  for (unsigned int i = 0; i < reservedWords.size(); ++i) {
                    if (reservedWords.at(i) == temp) {
                      string errormessage;
                      errormessage = "ERROR on line " + to_string(currLine) + ": declared reserved word " + temp + "\n";
                      errors += errormessage;
                    }
                  }
                  
                  if (variableSet.count(temp) != 0) {
                    string errormessage;
                    errormessage = "ERROR on line " +  to_string(currLine) + ": redeclaration of variable " + temp + "\n";
                    errors += errormessage;
                  }
                  else if (isReserved){
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": invalid declaration of reserved word " + temp + "\n";
                    errors += errormessage;
                  }
                  else {
                    variableSet.insert(temp);
                  }
                }
                | ident COMMA decInner 
                {
                  // Check for declaration of a reserved word (test 05)
                  string temp = $1.result_id;
                  for (unsigned int i = 0; i < reservedWords.size(); ++i) {
                    if (reservedWords.at(i) == temp) {
                      string errormessage;
                      errormessage = "ERROR on line " + to_string(currLine) + ": declared reserved word " + temp + "\n";
                      errors += errormessage;
                    }
                  } 

                  // string temp = $1.result_id; 
                  if (variableSet.count(temp) != 0) {
                    string errormessage;
                    errormessage = "ERROR on line " +  to_string(currLine) + ": redeclaration of variable " + temp + "\n";
                    errors += errormessage;
                  }
                  else if (isReserved){
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": invalid declaration of reserved word " + temp + "\n";
                    errors += errormessage;
                  }
                  else {
                    variableSet.insert(temp);
                  }

                  
                  ostringstream oss; 
                  oss << $1.result_id << "#" << $3.result_id;
                  $$.result_id = strdup(oss.str().c_str());
                }
                ;
statement:      var ASSIGN expression
                {
				  if ($1.is_array){
				    ostringstream oss;
				    oss << $1.code;
				    oss << $3.code;
				    oss << "[]= " << $1.arr_name << ", " <<  $1.result_id << ", " 	<< $3.result_id << endl;
				    $$.code = strdup(oss.str().c_str());
				  }
				  else {
				    ostringstream oss;
                    oss << $3.code;
				    oss << "= " << $1.result_id << ", " << $3.result_id << endl;
				    $$.code = strdup(oss.str().c_str());
				  }
                }
                | IF bool_expr THEN stateInnerOne ENDIF
                {
                  string l = new_label();
                  string m = new_label();
                  ostringstream oss;

                  oss << $2.code;
                  oss << "?:= " << l << ", " << $2.result_id << endl;
                  oss << ":= " << m << endl;
                  oss << ": " << l << endl;
                  oss << $4.code;
                  oss << ": " << m << endl;

                  $$.code = strdup(oss.str().c_str());
                }
                | IF bool_expr THEN stateInnerOne ELSE stateInnerOne ENDIF 
				{
				  string l = new_label();
				  string m = new_label();
				  ostringstream oss;
				  
				  oss << $2.code;
				  oss << "?:= " << l << ", " << $2.result_id << endl;
				  oss << ":= " << m << endl;
				  oss << ": " << l << endl;
				  oss << $4.code;
				  oss << ": " << m << endl;
				  oss << $6.code;	
				  
				  $$.code = strdup(oss.str().c_str());
				}
                | WHILE bool_expr BEGINLOOP stateInnerOne ENDLOOP
				{
				  string l = new_label();
				  string m = new_label();
				  string n = new_label();
				  ostringstream oss;
				  
				  if ($4.label == NULL){
					  oss << ": " << n << endl;
					  oss << $2.code;
					  oss << "?:= " << l << ", " << $2.result_id << endl;
					  oss << ":= " << m << endl;
					  oss << ": " << l << endl;
				
					  oss << $4.code;
					  oss << ":= " << n << endl;
					  oss << ": " << m << endl;
				  }
				  else {
					  oss << ": " << n << endl;
					  oss << $2.code;
					  oss << "?:= " << l << ", " << $2.result_id << endl;
					  oss << ":= " << m << endl;
					  oss << ": " << l << endl;
				
					  oss << $4.code;
					  oss << ": " << $4.label << endl;	
					  oss << ":= " << n << endl;
					  oss << ": " << m << endl;
					  
				  }
				  

				  $$.code = strdup(oss.str().c_str());
				  
				}
                | DO BEGINLOOP stateInnerOne ENDLOOP WHILE bool_expr 
                {
				  string l = new_label();
				  string m = new_label();
				  string n = new_label();
				  ostringstream oss;
				  				  
				  if (strlen($3.label) <= 0){
					  oss << ": " << l << endl;
					  oss << $3.code << $6.code;
					  oss << "?:= " << l << ", " << $6.result_id << endl;  
				  }
				  else {
					  oss << ": " << l << endl;
					  oss << $3.code;
					  oss << ": " << $3.label << endl;
					  oss << $6.code;
					  oss << "?:= " << l << ", " << $6.result_id << endl;
				  }

				  $$.code = strdup(oss.str().c_str());
				  
				}
                | FOR var ASSIGN NUMBER SEMICOLON bool_expr SEMICOLON var ASSIGN expression BEGINLOOP stateInnerOne ENDLOOP 
                {}
                | READ stateInnerTwo 
                {
				  ostringstream oss;
				  oss << $2.code;
				  if (strchr($2.result_id, '#') == NULL){
					  if ($2.is_array){
						  oss << ".[]< " << $2.arr_name << ", " << $2.result_id << endl;
						  $$.code = strdup(oss.str().c_str());
						  $$.result_id = $2.result_id;
					  }
					  else {
						  oss << ".< " << $2.result_id << endl;
						  $$.code = strdup(oss.str().c_str());
						  $$.result_id = $2.result_id;
					  }			  
				  }
				  else {
					  int count = 0;
					  char curr = $2.result_id[0];
					  
					  while (count < strlen($2.result_id)){
					    curr = $2.result_id[count];
					    ostringstream lss;

					    while ((curr != '#') && count < strlen($2.result_id)){
						  lss << curr;
						  count += 1;
						  curr = $2.result_id[count];
						}
						oss << ".< " << lss.str().c_str() << endl;
						count += 1;
					  }
				  }  
				  $$.code = strdup(oss.str().c_str());				
                }
                | WRITE stateInnerTwo 
                {
				  
				  ostringstream oss;
				  oss << $2.code;
				  
				  if (strchr($2.result_id, '#') == NULL){
					  if ($2.is_array){
						  oss << ".[]> " << $2.arr_name << ", " << $2.result_id << endl;
						  $$.code = strdup(oss.str().c_str());
						  $$.result_id = $2.result_id;
					  }
					  else {
						  oss << ".> " << $2.result_id << endl;
						  $$.code = strdup(oss.str().c_str());
						  $$.result_id = $2.result_id;
					  }
				  }
				  else {
					  int count = 0;
					  char curr = $2.result_id[0];
					  
					  while (count < strlen($2.result_id)){
					    curr = $2.result_id[count];
					    ostringstream lss;
					    
					    while ((curr != '#') && count < strlen($2.result_id)){
						  lss << curr;
						  count += 1;
						  curr = $2.result_id[count];
						}
						oss << ".> " << lss.str().c_str() << endl;
						count += 1;
					  }
				  }  
				  $$.code = strdup(oss.str().c_str());	
				}
                | CONTINUE 
                {
                  ostringstream oss;
                  string l = new_label();
                  oss << ":= " << l << endl;
                  $$.label = strdup(l.c_str());
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(l.c_str());
                }
                | RETURN expression 
                {
                  ostringstream oss;
                  oss << $2.code;
                  oss << "ret " << $2.result_id << endl;
                  $$.code = strdup(oss.str().c_str());
                }
                ;
stateInnerOne:  statement SEMICOLON stateInnerOne 
				{
				  ostringstream oss;
				  oss << $1.code << $3.code;
				  $$.code = strdup(oss.str().c_str());
				  
				  ostringstream ossStatementLabel;
				  ostringstream ossStateInnerOneLabel;
				  
				  ossStatementLabel << $1.label;
				  ossStateInnerOneLabel << $3.label;
				  
				  /*if (strstr($1.code, "label") != NULL){
					  $$.label = $1.label;
					  cout << "here" << $$.label << endl;
				  }*/
				  
				  if (ossStatementLabel.str().length() > 0) {
					  $$.label = strdup(ossStatementLabel.str().c_str());
			      } else {
					  $$.label = strdup(ossStateInnerOneLabel.str().c_str());
			      }
				}
                | statement SEMICOLON 
				{ 
				  $$.code = $1.code;
				  $$.result_id = $1.result_id;
				  
				  ostringstream oss;
				  oss << $1.label;
				  string label = oss.str();
				  				  
				  if (label.length() > 0) {
					  $$.label = $1.label;
				  } else {
					  $$.label = "";
				  }
				 }
                ;
stateInnerTwo:  var 
				{
				  if ($1.is_array){
					  $$.code = $1.code;
					  $$.result_id = $1.result_id;
					  $$.is_array = TRUE;
					  $$.arr_name = $1.arr_name;
				  }
				  else {
					  $$.code = $1.code;
					  $$.result_id = $1.result_id;
				  }
				}
                | var COMMA stateInnerTwo 
			    {
				  ostringstream oss;
				  oss << $1.result_id << "#" << $3.result_id;
				  $$.result_id = strdup(oss.str().c_str());
			    }
                ;
bool_expr:      relation_and_expr
                {
                  $$.code = $1.code;
                  $$.result_id = $1.result_id;
                }
                | relation_and_expr OR bool_expr 
                {
                  ostringstream oss; 
                  string x = new_temp();
                  oss << $1.code << $3.code;
                  oss << ". " << x << endl;
                  oss << "|| " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                  
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());
                }
                ;
relation_and_expr:  relation_expr 
                    {
                      $$.code = $1.code;
                      $$.result_id = $1.result_id;
                    }
                    | relation_expr AND relation_and_expr  
                    {
                      ostringstream oss;
                      string x = new_temp();
                      oss << $1.code << $3.code;
                      oss << ". " << x << endl;
                      oss << "&& " << x << 	", " << $1.result_id << ", " << $3.result_id << endl;
                      
                      $$.code = strdup(oss.str().c_str());
                      $$.result_id = strdup(x.c_str());
                    }
                    ;
relation_expr:  expression comp expression
                {
                  ostringstream oss;
                  string x = new_temp();
				  oss << $1.code << $3.code;
                  oss << ". " << x << endl;
                  oss << $2.optr << " " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());
                }
                | TRUE 
                {
				  ostringstream oss;
				  oss << "1";
				  $$.code = "";
				  $$.result_id = strdup(oss.str().c_str());
				}
                | FALSE 
                {
				  ostringstream oss;
				  oss << "0";
				  $$.code = "";
				  $$.result_id = strdup(oss.str().c_str());				
				}
                | 
                L_PAREN bool_expr R_PAREN 
                {
				  $$.code = $2.code;
				  $$.result_id = $2.result_id;
				}
                | NOT expression comp expression 
                {
				  ostringstream oss;
                  string x = new_temp();
				  oss << $2.code << $4.code;
                  oss << "!. " << x << endl;
                  oss << $3.optr << " " << x << ", " << $2.result_id << ", " << $4	.result_id << endl;
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());
				}
                | NOT TRUE 
                {
				  ostringstream oss;
				  oss << "!1";
				  $$.code = "";
				  $$.result_id = strdup(oss.str().c_str());
				}
                | NOT FALSE 
                {
				  ostringstream oss;
				  oss << "!0";
				  $$.code = "";
				  $$.result_id = strdup(oss.str().c_str());	
				}
                | NOT L_PAREN bool_expr R_PAREN 
                {
				  ostringstream oss;
				  oss << "! " << $3.result_id;
				  $$.code = $3.code;
				  $$.result_id = strdup(oss.str().c_str());
				}
                ;
comp:           EQ
                {
                  $$.optr = "==";
                }
                | NEQ
                {
                  $$.optr = "!=";
                }
                | LT
                {
                  $$.optr = "<";
                }
                | GT
                {
                  $$.optr = ">";
                }
                | LTE
                {
                  $$.optr = "<=";
                }
                | GTE
                {
                  $$.optr = ">=";
                }
                ;
expression:     multiplicative_expr
                {                  
                  $$.result_id = $1.result_id;
                  $$.code = $1.code;
                }
                | multiplicative_expr ADD expression
                {
                  ostringstream oss;
                  oss << $1.code << $3.code;
                  string x = new_temp();
                  oss << ". " << x << endl;
                  oss << "+ " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());
                }
                | multiplicative_expr SUB expression
                {
                  ostringstream oss;
                  oss << $1.code << $3.code;
                  string x = new_temp();
                  oss << ". " << x << endl;
                  oss << "- " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());
                }
                ;
multiplicative_expr:  term
                      {	
						if (strlen($1.code) > 0){
						  if ($1.is_array){
							ostringstream oss;
							string x = new_temp();
							
							oss << $1.code;
							oss << ". " << x << endl;
							oss << "=[] " << x << ", " << $1.arr_name << ", " << $1.result_id << endl;
							$$.code = strdup(oss.str().c_str());
						    $$.result_id = strdup(x.c_str());
						  }
						  else {
							$$.code = $1.code;
						    $$.result_id = $1.result_id;
						  }
		
						}	 
						else {
						  ostringstream oss;
						  string x = new_temp();
						  oss << ". " << x << endl;
						  oss << "= " << x << ", " << $1.result_id << endl;
						  $$.code = strdup(oss.str().c_str());
						  $$.result_id = strdup(x.c_str());
						}
                      }
                      | term MULT multiplicative_expr
                      {
                        ostringstream oss;
                        oss << $1.code << $3.code;
                        string x = new_temp();
                        oss << ". " << x << endl;
                        oss << "* " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                        $$.code = strdup(oss.str().c_str());
                        $$.result_id = strdup(x.c_str());
                      }
                      | term DIV multiplicative_expr 
                      {
                        ostringstream oss;
                        string x = new_temp();
                        oss << $1.code << $3.code;
                        oss << ". " << x << endl;
                        oss << "/ " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                        $$.code = strdup(oss.str().c_str());
                        $$.result_id = strdup(x.c_str()); 
                      }
                      | term MOD multiplicative_expr 
                      {
                        ostringstream oss;
                        oss << $1.code << $3.code;
                        string x = new_temp();
                        oss << ". " << x << endl;
                        oss << "% " << x << ", " << $1.result_id << ", " << $3.result_id << endl;
                        $$.code = strdup(oss.str().c_str());
                        $$.result_id = strdup(x.c_str());
                      }
                      ;
term:           var
                {
                  
                  $$.result_id = $1.result_id;
                }
                | NUMBER
                {
			      $$.code = "";		 	
                  $$.result_id = strdup(to_string($1).c_str());
                }
                | L_PAREN expression R_PAREN 
                {
				  $$.code = $2.code;
				  $$.result_id = $2.result_id;
				}
                | SUB var 
                {
					ostringstream oss;
					oss << "- " << $2.result_id << endl;
					$$.result_id = strdup(oss.str().c_str());
				}
                | SUB NUMBER 
                {
					ostringstream oss;
				    $$.result_id = strdup(to_string($2).c_str());
					oss << "- " << $$.result_id << endl;
					$$.result_id = strdup(oss.str().c_str());
					$$.code = "";
				}
                | SUB L_PAREN expression R_PAREN 
                {
					$$.code = $3.code;
					ostringstream oss;
					oss << "- " << $3.result_id << endl;
					$$.result_id = strdup(oss.str().c_str());
				}
                | ident L_PAREN termInnerOne R_PAREN 
                {
                  // Check if function has been defined (test 02)
                  string temp = $1.result_id;
                  if (functionSet.count(temp) == 0) {
                    string errormessage;
                    errormessage = "ERROR on line " + to_string(currLine) + ": function " + temp + " has not been defined\n";
                    errors += errormessage;
                  }
                  
                  ostringstream oss;
                  oss << $3.code;
                  string x = new_temp();
                  oss << "param " << $3.result_id << endl;
                  oss << ". " << x << endl;
                  oss << "call " << $1.result_id << ", " << x << endl;
                  $$.code = strdup(oss.str().c_str());
                  $$.result_id = strdup(x.c_str());		  
                }
                ;
termInnerOne:   expression COMMA termInnerOne 
				{
					ostringstream oss;
					oss << $1.code << $3.code;
					$$.code = strdup(oss.str().c_str());
				}
                | expression 
                {
                  $$.code = $1.code;
                          $$.result_id = $1.result_id;
                }
                | 
                {
                  $$.code = "";
                  $$.result_id = "";
                }
                ;
var:            ident
                { 
                  // string temp = $1.result_id;
                  // if (!variableSet.count(temp)) {
                  //   string errormessage;
                  //   errormessage = "ERROR on line " +  to_string(currLine) + ": use of undeclared variable " + temp + "\n";
                  //   errors += errormessage;
                  // } 
                  
                  $$.code = "";
                  $$.result_id = $1.result_id;
                }
                | ident L_SQUARE_BRACKET expression R_SQUARE_BRACKET
                {
                  // string temp = $1.result_id;
                  // if (variableSet.count(temp) != 0) {
                  //   string errormessage;
                  //   errormessage = "ERROR on line " +  to_string(currLine) + ": use of undeclared variable " + temp + "\n";
                  //   errors += errormessage;
                  // } 
                  
                  $$.arr_name = $1.result_id;
                  $$.result_id = $3.result_id;
                  $$.is_array = TRUE;
                  $$.code = $3.code;
                }
                ;
%%

void yyerror(const char* s) {
   printf("ERROR: %s at symbol \"%s\" on line %d, col %d\n", s, yytext, currLine, currPos);
}
