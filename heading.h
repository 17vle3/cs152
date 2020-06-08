#define YY_NO_UNPUT
#include <iostream>
#include <vector>
#include <stack>
#include <map>
#include <sstream>
#include <fstream>
#include <stdio.h>
#include <string>
using namespace std;

struct Terminal{
   stringstream *code;
   string *place;
   string *value;
   string *offset;
   string *op;
   string *begin;
   string *parent;
   string *end;
   Type type;
   int length;
   string *index;
   vector<string> *ids;
   vector<Var> *vars; 
};
