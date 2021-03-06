// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:_foreign_helper' show JS, JS_GET_NAME;
import 'dart:_js_embedded_names' show JsGetName;
import 'dart:_rti' as rti;
import "package:expect/expect.dart";

final String objectName = JS_GET_NAME(JsGetName.OBJECT_CLASS_TYPE_NAME);
final String futureName = JS_GET_NAME(JsGetName.FUTURE_CLASS_TYPE_NAME);
final String nullName = JS_GET_NAME(JsGetName.NULL_CLASS_TYPE_NAME);

const typeRulesJson = r'''
{
  "int": {"num": []},
  "double": {"num": []},
  "List": {"Iterable": ["1"]},
  "CodeUnits": {
    "List": ["int"],
    "Iterable": ["int"]
  }
}
''';
final typeRules = JS('=Object', 'JSON.parse(#)', typeRulesJson);
final universe = rti.testingCreateUniverse();

main() {
  rti.testingAddRules(universe, typeRules);
  runTests();
  runTests(); // Ensure caching didn't change anything.
}

void runTests() {
  testInterfaces();
  testTopTypes();
  testNull();
  testFutureOr();
  testFunctions();
  testGenericFunctions();
}

void testInterfaces() {
  strictSubtype('List<CodeUnits>', 'Iterable<List<int>>');
  strictSubtype('CodeUnits', 'Iterable<num>');
  strictSubtype('Iterable<int>', 'Iterable<num>');
  unrelated('int', 'CodeUnits');
  equivalent('double', 'double');
  equivalent('List<int>', 'List<int>');
}

void testTopTypes() {
  strictSubtype('List<int>', objectName);
  equivalent(objectName, objectName);
  equivalent('@', '@');
  equivalent('~', '~');
  equivalent('1&', '1&');
  equivalent(objectName, '@');
  equivalent(objectName, '~');
  equivalent(objectName, '1&');
  equivalent('@', '~');
  equivalent('@', '1&');
  equivalent('~', '1&');
  equivalent('List<$objectName>', 'List<@>');
  equivalent('List<$objectName>', 'List<~>');
  equivalent('List<$objectName>', 'List<1&>');
  equivalent('List<@>', 'List<~>');
  equivalent('List<@>', 'List<1&>');
  equivalent('List<~>', 'List<1&>');
}

void testNull() {
  strictSubtype(nullName, 'int');
  strictSubtype(nullName, 'Iterable<CodeUnits>');
  strictSubtype(nullName, objectName);
  equivalent(nullName, nullName);
}

void testFutureOr() {
  strictSubtype('$futureName<int>', '$futureName<num>');
  strictSubtype('int', 'int/');
  strictSubtype('$futureName<int>', 'int/');
  strictSubtype('int/', 'num/');
  strictSubtype('int', 'num/');
  strictSubtype('$futureName<int>', 'num/');
  equivalent('@/', '~/');
}

void testFunctions() {
  equivalent('~()', '~()');
  equivalent('@()', '~()');
  unrelated('int()', 'int(int)');
  strictSubtype('int()', 'num()');
  strictSubtype('~(num)', '~(int)');
  strictSubtype('int(Iterable<num>)', 'num(CodeUnits)');

  equivalent('~(int,@,num)', '~(int,@,num)');
  equivalent('@(int,~,num)', '~(int,@,num)');
  unrelated('int(int,double)', 'void(String)');
  unrelated('int(int,double)', 'int(int)');
  unrelated('int(int,double)', 'int(double)');
  unrelated('int(int,double)', 'int(int,int)');
  unrelated('int(int,double)', 'int(String,double)');
  strictSubtype('int(int,double)', '~(int,double)');
  strictSubtype('int(int,double)', 'num(int,double)');
  strictSubtype('int(num,double)', 'int(int,double)');
  strictSubtype('int(int,num)', 'int(int,double)');
  strictSubtype('int(num,num)', 'int(int,double)');
  strictSubtype('double(num,Iterable<num>,int/)', 'num(int,CodeUnits,int)');

  equivalent('~([@])', '~([@])');
  equivalent('~(int,[double])', '~(int,[double])');
  equivalent('~(int,[double,CodeUnits])', '~(int,[double,CodeUnits])');
  unrelated('~([int])', '~([double])');
  unrelated('~(int,[int])', '~(int,[double])');
  unrelated('~(int,[CodeUnits,int])', '~(int,[CodeUnits,double])');
  strictSubtype('~([num])', '~([int])');
  strictSubtype('~([num,num])', '~([int,double])');
  strictSubtype('~([int,double])', '~(int,[double])');
  strictSubtype('~([int,double,CodeUnits])', '~([int,double])');
  strictSubtype('~([int,double,CodeUnits])', '~(int,[double])');

  equivalent('~({foo:@})', '~({foo:@})');
  unrelated('~({foo:@})', '~({bar:@})');
  unrelated('~({foo:@,quux:@})', '~({bar:@,baz:@})');
  unrelated('~(@,{foo:@})', '~(@,@)');
  unrelated('~(@,{foo:@})', '~({bar:@,foo:@})');
  equivalent('~({bar:int,foo:double})', '~({bar:int,foo:double})');
  strictSubtype('~({bar:int,foo:double})', '~({bar:int})');
  strictSubtype('~({bar:int,foo:double})', '~({foo:double})');
  strictSubtype('~({bar:num,baz:num,foo:num})', '~({baz:int,foo:double})');
}

void testGenericFunctions() {
  equivalent('~()<int>', '~()<int>');
  unrelated('~()<int>', '~()<double>');
  unrelated('~()<int>', '~()<int,int>');
  unrelated('~()<int>', '~()<num>');
  unrelated('~()<int,double>', '~()<double,int>');
  strictSubtype('List<0^>()<int>', 'Iterable<0^>()<int>');
  strictSubtype('~(Iterable<0^>)<int>', '~(List<0^>)<int>');

  equivalent('~()<@>', '~()<~>');
  equivalent('~()<List<@/>>', '~()<List<~/>>');
  unrelated('~()<List<int/>>', '~()<List<num/>>');
}

String reason(String s, String t) => "$s <: $t";

void strictSubtype(String s, String t) {
  var sRti = rti.testingUniverseEval(universe, s);
  var tRti = rti.testingUniverseEval(universe, t);
  Expect.isTrue(rti.testingIsSubtype(universe, sRti, tRti), reason(s, t));
  Expect.isFalse(rti.testingIsSubtype(universe, tRti, sRti), reason(t, s));
}

void unrelated(String s, String t) {
  var sRti = rti.testingUniverseEval(universe, s);
  var tRti = rti.testingUniverseEval(universe, t);
  Expect.isFalse(rti.testingIsSubtype(universe, sRti, tRti), reason(s, t));
  Expect.isFalse(rti.testingIsSubtype(universe, tRti, sRti), reason(t, s));
}

void equivalent(String s, String t) {
  var sRti = rti.testingUniverseEval(universe, s);
  var tRti = rti.testingUniverseEval(universe, t);
  Expect.isTrue(rti.testingIsSubtype(universe, sRti, tRti), reason(s, t));
  Expect.isTrue(rti.testingIsSubtype(universe, tRti, sRti), reason(t, s));
}
