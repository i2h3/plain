// CGenerator.swift — PLAIN AST → C source code

struct CGenerator {

    private var output: String = ""
    private var indentLevel: Int = 0
    private let indent = "    "

    mutating func generate(program: Program) -> String {
        output = ""
        emitPreamble()
        for decl in program.declarations {
            emitDeclaration(decl)
        }
        emitMainEntryPoint(program: program)
        return output
    }

    // MARK: — Preamble

    private mutating func emitPreamble() {
        emit("#include \"plain_runtime.h\"")
        emit("")
    }

    // MARK: — Declarations

    private mutating func emitDeclaration(_ decl: Declaration) {
        switch decl {
        case .function(let f):      emitFunction(f)
        case .taskFunction(let t):  emitTaskFunction(t)
        case .classDecl(let c):     emitClass(c)
        case .featureDecl:          break // features become vtables — TODO
        case .errorDecl(let e):     emitErrorDecl(e)
        case .letDecl(let l):       emitLetDecl(l)
        case .varDecl(let v):       emitVarDecl(v)
        case .sharedVarDecl(let s): emitSharedVarDecl(s)
        case .statement(let s):     emitStatement(s)
        }
    }

    // MARK: — Functions

    private mutating func emitFunction(_ f: FunctionDecl) {
        let returnType = f.returnType.map(cType) ?? "void"
        let params = f.params.map { "\(cType($0.type)) \($0.name)" }.joined(separator: ", ")
        emit("\(returnType) plain_\(f.name)(\(params)) {")
        indentLevel += 1
        for stmt in f.body { emitStatement(stmt) }
        indentLevel -= 1
        emit("}")
        emit("")
    }

    private mutating func emitTaskFunction(_ t: TaskFunctionDecl) {
        // Task functions are emitted as regular C functions for now.
        // A full implementation would use pthreads or a coroutine library.
        let returnType = t.returnType.map(cType) ?? "void"
        let params = t.params.map { "\(cType($0.type)) \($0.name)" }.joined(separator: ", ")
        emit("// task function")
        emit("\(returnType) plain_\(t.name)(\(params)) {")
        indentLevel += 1
        for stmt in t.body { emitStatement(stmt) }
        indentLevel -= 1
        emit("}")
        emit("")
    }

    // MARK: — Classes

    private mutating func emitClass(_ c: ClassDecl) {
        emit("// class \(c.name)")
        emit("typedef struct plain_\(c.name) {")
        indentLevel += 1
        if let parent = c.parent {
            emit("plain_\(parent) base;")
        }
        emit("plain_refcount_t refcount;")
        for prop in c.properties {
            emit("\(cType(prop.type)) \(prop.name);")
        }
        indentLevel -= 1
        emit("} plain_\(c.name);")
        emit("")

        // Constructor
        let params = c.properties.map { "\(cType($0.type)) \($0.name)" }.joined(separator: ", ")
        emit("plain_\(c.name)* plain_\(c.name)_create(\(params)) {")
        indentLevel += 1
        emit("plain_\(c.name)* self = plain_alloc(sizeof(plain_\(c.name)));")
        for prop in c.properties {
            emit("self->\(prop.name) = \(prop.name);")
        }
        emit("return self;")
        indentLevel -= 1
        emit("}")
        emit("")

        // Methods
        for method in c.methods {
            let returnType = method.returnType.map(cType) ?? "void"
            let methodParams = (["plain_\(c.name)* self"] + method.params.map { "\(cType($0.type)) \($0.name)" }).joined(separator: ", ")
            emit("\(returnType) plain_\(c.name)_\(method.name)(\(methodParams)) {")
            indentLevel += 1
            for stmt in method.body { emitStatement(stmt) }
            indentLevel -= 1
            emit("}")
            emit("")
        }
    }

    private mutating func emitErrorDecl(_ e: ErrorDecl) {
        emit("typedef struct plain_error_\(e.name) {")
        indentLevel += 1
        emit("plain_error_base_t base;")
        for param in e.params {
            emit("\(cType(param.type)) \(param.name);")
        }
        indentLevel -= 1
        emit("} plain_error_\(e.name);")
        emit("")
    }

    // MARK: — Variable declarations

    private mutating func emitLetDecl(_ l: LetDecl) {
        let type = l.type.map(cType) ?? "plain_auto_t"
        emit("const \(type) \(l.name) = \(emitExpr(l.value));")
    }

    private mutating func emitVarDecl(_ v: VarDecl) {
        let type = v.type.map(cType) ?? "plain_auto_t"
        if let value = v.value {
            emit("\(type) \(v.name) = \(emitExpr(value));")
        } else {
            emit("\(type) \(v.name);")
        }
    }

    private mutating func emitSharedVarDecl(_ s: SharedVarDecl) {
        let type = s.type.map(cType) ?? "plain_auto_t"
        emit("// shared var — mutex wrapped")
        if let value = s.value {
            emit("plain_shared_\(type) \(s.name) = PLAIN_SHARED_INIT(\(emitExpr(value)));")
        } else {
            emit("plain_shared_\(type) \(s.name);")
        }
    }

    // MARK: — Statements

    private mutating func emitStatement(_ stmt: Statement) {
        switch stmt {
        case .set(let s):      emitSetStatement(s)
        case .returnStmt(let r): emitReturnStatement(r)
        case .ifStmt(let i):   emitIfStatement(i)
        case .whileStmt(let w):emitWhileStatement(w)
        case .forRange(let f): emitForRangeStatement(f)
        case .forEach(let f):  emitForEachStatement(f)
        case .parallel(let p): emitParallelStatement(p)
        case .tryCatch(let t): emitTryCatch(t)
        case .throwStmt(let t):emitThrow(t)
        case .print(let p):    emitPrint(p)
        case .send(let s):     emitSend(s)
        case .close(let c):    emit("plain_channel_close(\(emitExpr(c.channel)));")
        case .run(let r):      emitRun(r)
        case .add(let a):      emit("plain_list_add(&\(emitExpr(a.collection)), \(emitExpr(a.value)));")
        case .remove(let r):   emit("plain_list_remove(&\(emitExpr(r.collection)), \(emitExpr(r.value)));")
        case .write(let w):    emit("plain_file_write(\(emitExpr(w.path)), \(emitExpr(w.content)));")
        case .append(let a):   emit("plain_file_append(\(emitExpr(a.path)), \(emitExpr(a.content)));")
        case .createDirectory(let p): emit("plain_dir_create(\(emitExpr(p)));")
        case .deleteFile(let p):      emit("plain_file_delete(\(emitExpr(p)));")
        case .deleteDirectory(let p): emit("plain_dir_delete(\(emitExpr(p)));")
        case .copyFile(let f, let t): emit("plain_file_copy(\(emitExpr(f)), \(emitExpr(t)));")
        case .moveFile(let f, let t): emit("plain_file_move(\(emitExpr(f)), \(emitExpr(t)));")
        case .clearTerminal:   emit("plain_terminal_clear();")
        case .exitStmt(let e): emit("exit(\(emitExpr(e.code)));")
        case .expression(let e): emit("\(emitExpr(e));")
        }
    }

    private mutating func emitSetStatement(_ s: SetStatement) {
        switch s.target {
        case .variable(let name):
            emit("\(name) = \(emitExpr(s.value));")
        case .property(let obj, let prop):
            emit("\(emitExpr(obj))->\(prop) = \(emitExpr(s.value));")
        case .listItem(let index, let list):
            emit("plain_list_set(&\(emitExpr(list)), \(emitExpr(index)), \(emitExpr(s.value)));")
        case .mapEntry(let key, let map):
            emit("plain_map_set(&\(emitExpr(map)), \(emitExpr(key)), \(emitExpr(s.value)));")
        }
    }

    private mutating func emitReturnStatement(_ r: ReturnStatement) {
        if let value = r.value {
            emit("return \(emitExpr(value));")
        } else {
            emit("return;")
        }
    }

    private mutating func emitIfStatement(_ i: IfStatement) {
        emit("if (\(emitExpr(i.condition))) {")
        indentLevel += 1
        for stmt in i.thenBody { emitStatement(stmt) }
        indentLevel -= 1
        for (cond, body) in i.elseIfs {
            emit("} else if (\(emitExpr(cond))) {")
            indentLevel += 1
            for stmt in body { emitStatement(stmt) }
            indentLevel -= 1
        }
        if let elseBody = i.elseBody {
            emit("} else {")
            indentLevel += 1
            for stmt in elseBody { emitStatement(stmt) }
            indentLevel -= 1
        }
        emit("}")
    }

    private mutating func emitWhileStatement(_ w: WhileStatement) {
        emit("while (\(emitExpr(w.condition))) {")
        indentLevel += 1
        for stmt in w.body { emitStatement(stmt) }
        indentLevel -= 1
        emit("}")
    }

    private mutating func emitForRangeStatement(_ f: ForRangeStatement) {
        emit("for (int64_t \(f.variable) = \(emitExpr(f.from)); \(f.variable) <= \(emitExpr(f.to)); \(f.variable)++) {")
        indentLevel += 1
        for stmt in f.body { emitStatement(stmt) }
        indentLevel -= 1
        emit("}")
    }

    private mutating func emitForEachStatement(_ f: ForEachStatement) {
        emit("PLAIN_FOR_EACH(\(f.variable), \(emitExpr(f.collection))) {")
        indentLevel += 1
        for stmt in f.body { emitStatement(stmt) }
        indentLevel -= 1
        emit("}")
    }

    private mutating func emitParallelStatement(_ p: ParallelStatement) {
        emit("// parallel block — TODO: dispatch with pthreads")
        emit("{")
        indentLevel += 1
        for decl in p.declarations { emitDeclaration(decl) }
        indentLevel -= 1
        emit("}")
    }

    private mutating func emitTryCatch(_ t: TryCatchStatement) {
        emit("plain_try_begin();")
        emit("if (setjmp(plain_try_env()) == 0) {")
        indentLevel += 1
        for stmt in t.body { emitStatement(stmt) }
        indentLevel -= 1
        for clause in t.catches {
            if let type = clause.errorType {
                emit("} else if (plain_catch_is(PLAIN_ERROR_TYPE_\(type.uppercased()))) {")
            } else {
                emit("} else {")
            }
            indentLevel += 1
            emit("plain_error_t* \(clause.binding) = plain_catch_error();")
            for stmt in clause.body { emitStatement(stmt) }
            indentLevel -= 1
        }
        emit("}")
        emit("plain_try_end();")
    }

    private mutating func emitThrow(_ t: ThrowStatement) {
        let args = t.args.map { "\(emitExpr($0.1))" }.joined(separator: ", ")
        emit("plain_throw(plain_error_\(t.errorName)_create(\(args)));")
    }

    private mutating func emitPrint(_ p: PrintStatement) {
        let dest = p.destination == .error ? "stderr" : "stdout"
        let value = emitExpr(p.value)
        if let color = p.color {
            emit("plain_print_styled(\(dest), \(value), \(emitExpr(color)), \(p.style.map { "\"\($0)\"" } ?? "NULL"));")
        } else {
            emit("plain_print(\(dest), \(value));")
        }
    }

    private mutating func emitSend(_ s: SendStatement) {
        emit("plain_channel_send(\(emitExpr(s.channel)), \(emitExpr(s.value)));")
    }

    private mutating func emitRun(_ r: RunStatement) {
        let args = r.args.map { emitExpr($0.1) }.joined(separator: ", ")
        emit("plain_\(r.name)(\(args));")
    }

    // MARK: — Expressions

    private func emitExpr(_ expr: Expression) -> String {
        switch expr {
        case .text(let s):    return "plain_text_literal(\"\(escaped(s))\")"
        case .number(let n):  return "\(n)LL"
        case .decimal(let d): return "\(d)"
        case .bool(let b):    return b ? "1" : "0"
        case .nothing:        return "NULL"
        case .this:           return "self"
        case .identifier(let name): return name

        case .propertyAccess(let obj, let prop):
            return "\(emitExpr(obj))->\(prop)"

        case .methodCall(let obj, let name, let args):
            let a = args.map { emitExpr($0.1) }.joined(separator: ", ")
            return "\(emitExpr(obj))_\(name)(\(emitExpr(obj)), \(a))"

        case .functionCall(let name, let args):
            let a = args.map { emitExpr($0.1) }.joined(separator: ", ")
            return "plain_\(name)(\(a))"

        case .awaitExpr(let inner):
            return emitExpr(inner) // simplified — full implementation awaits thread

        case .binary(let l, let op, let r):
            return emitBinary(l, op, r)

        case .unary(let op, let expr):
            switch op {
            case .not:    return "!(\(emitExpr(expr)))"
            case .negate: return "-(\(emitExpr(expr)))"
            }

        case .inlineIf(let cond, let then, let els):
            return "(\(emitExpr(cond)) ? \(emitExpr(then)) : \(emitExpr(els)))"

        case .listLiteral(let items):
            let elements = items.map { emitExpr($0) }.joined(separator: ", ")
            return "plain_list_literal(\(items.count), \(elements))"

        case .dictionaryLiteral(let pairs):
            let elements = pairs.map { "{ \(emitExpr($0.0)), \(emitExpr($0.1)) }" }.joined(separator: ", ")
            return "plain_map_literal(\(pairs.count), \(elements))"

        case .stdlibCall(let s):
            return emitStdlib(s)
        }
    }

    private func emitBinary(_ l: Expression, _ op: BinaryOp, _ r: Expression) -> String {
        switch op {
        case .add:
            // text concatenation vs numeric addition — type checker resolves
            return "plain_add(\(emitExpr(l)), \(emitExpr(r)))"
        case .subtract:      return "(\(emitExpr(l)) - \(emitExpr(r)))"
        case .multiply:      return "(\(emitExpr(l)) * \(emitExpr(r)))"
        case .divide:        return "(\(emitExpr(l)) / \(emitExpr(r)))"
        case .equal:         return "plain_equal(\(emitExpr(l)), \(emitExpr(r)))"
        case .notEqual:      return "!plain_equal(\(emitExpr(l)), \(emitExpr(r)))"
        case .greater:       return "(\(emitExpr(l)) > \(emitExpr(r)))"
        case .less:          return "(\(emitExpr(l)) < \(emitExpr(r)))"
        case .greaterEqual:  return "(\(emitExpr(l)) >= \(emitExpr(r)))"
        case .lessEqual:     return "(\(emitExpr(l)) <= \(emitExpr(r)))"
        case .and:           return "(\(emitExpr(l)) && \(emitExpr(r)))"
        case .or:            return "(\(emitExpr(l)) || \(emitExpr(r)))"
        case .inCollection:  return "plain_contains(\(emitExpr(r)), \(emitExpr(l)))"
        case .isPrefix:      return "plain_text_is_prefix(\(emitExpr(l)), \(emitExpr(r)))"
        case .isSuffix:      return "plain_text_is_suffix(\(emitExpr(l)), \(emitExpr(r)))"
        }
    }

    private func emitStdlib(_ s: StdlibExpr) -> String {
        switch s {
        case .uppercase(let t):    return "plain_text_uppercase(\(emitExpr(t)))"
        case .lowercase(let t):    return "plain_text_lowercase(\(emitExpr(t)))"
        case .trim(let t):         return "plain_text_trim(\(emitExpr(t)))"
        case .reverseText(let t):  return "plain_text_reverse(\(emitExpr(t)))"
        case .lengthOf(let t):     return "plain_text_length(\(emitExpr(t)))"
        case .positionsOf(let needle, let haystack):
            return "plain_text_positions(\(emitExpr(haystack)), \(emitExpr(needle)))"
        case .substring(let t, let f, let to):
            return "plain_text_substring(\(emitExpr(t)), \(emitExpr(f)), \(emitExpr(to)))"
        case .characterAt(let i, let t):
            return "plain_text_character_at(\(emitExpr(t)), \(emitExpr(i)))"
        case .partsOf(let t, let sep):
            return "plain_text_parts(\(emitExpr(t)), \(emitExpr(sep)))"
        case .wordsOf(let t):      return "plain_text_words(\(emitExpr(t)))"
        case .linesOf(let t):      return "plain_text_lines(\(emitExpr(t)))"
        case .joinOf(let list, let sep):
            let s = sep.map { emitExpr($0) } ?? "plain_text_literal(\"\")"
            return "plain_text_join(\(emitExpr(list)), \(s))"
        case .textFrom(let v):     return "plain_to_text(\(emitExpr(v)))"
        case .numberFrom(let t):   return "plain_text_to_number(\(emitExpr(t)))"
        case .decimalFrom(let t):  return "plain_text_to_decimal(\(emitExpr(t)))"
        case .round(let n, let p):
            return p.map { "plain_round_places(\(emitExpr(n)), \(emitExpr($0)))" } ?? "plain_round(\(emitExpr(n)))"
        case .floor(let n, let p):
            return p.map { "plain_floor_places(\(emitExpr(n)), \(emitExpr($0)))" } ?? "plain_floor(\(emitExpr(n)))"
        case .ceiling(let n, let p):
            return p.map { "plain_ceil_places(\(emitExpr(n)), \(emitExpr($0)))" } ?? "plain_ceil(\(emitExpr(n)))"
        case .absolute(let n):     return "plain_abs(\(emitExpr(n)))"
        case .squareRoot(let n):   return "plain_sqrt(\(emitExpr(n)))"
        case .powerOf(let b, let e): return "plain_pow(\(emitExpr(b)), \(emitExpr(e)))"
        case .remainder(let a, let b): return "(\(emitExpr(a)) % \(emitExpr(b)))"
        case .sumOf(let l):        return "plain_list_sum(\(emitExpr(l)))"
        case .averageOf(let l):    return "plain_list_average(\(emitExpr(l)))"
        case .randomNumber(let mn, let mx):
            if let mn = mn, let mx = mx {
                return "plain_random_between(\(emitExpr(mn)), \(emitExpr(mx)))"
            }
            return "plain_random_number()"
        case .randomDecimal:       return "plain_random_decimal()"
        case .randomBool:          return "plain_random_bool()"
        case .randomItemIn(let l): return "plain_random_item(\(emitExpr(l)))"
        case .shuffleOf(let l):    return "plain_list_shuffle(\(emitExpr(l)))"
        case .currentMoment:       return "plain_moment_now()"
        case .widthOfTerminal:     return "plain_terminal_width()"
        case .heightOfTerminal:    return "plain_terminal_height()"
        case .inputWith(let p):
            return p.map { "plain_input(\(emitExpr($0)))" } ?? "plain_input(NULL)"
        case .valueOfEnvironment(let k): return "plain_env_get(\(emitExpr(k)))"
        case .arguments:           return "plain_arguments()"
        case .operatingSystem:     return "plain_os_name()"
        case .homeDirectory:       return "plain_path_home()"
        case .temporaryDirectory:  return "plain_path_temp()"
        case .currentDirectory:    return "plain_path_cwd()"
        case .contentsOfFile(let p): return "plain_file_read(\(emitExpr(p)))"
        case .fileExists(let p):   return "plain_file_exists(\(emitExpr(p)))"
        case .directoryExists(let p): return "plain_dir_exists(\(emitExpr(p)))"
        case .sizeOfFile(let p):   return "plain_file_size(\(emitExpr(p)))"
        case .parseJson(let t):    return "plain_json_parse(\(emitExpr(t)))"
        case .jsonObject:          return "plain_json_object_new()"
        case .jsonOf(let v):       return "plain_json_encode(\(emitExpr(v)))"
        default:
            return "/* TODO: stdlib \(s) */"
        }
    }

    // MARK: — Entry point

    private mutating func emitMainEntryPoint(program: Program) {
        let hasTaskMain = program.declarations.contains {
            if case .taskFunction(let t) = $0, t.name == "main" { return true }
            return false
        }
        let hasMain = program.declarations.contains {
            if case .function(let f) = $0, f.name == "main" { return true }
            return false
        }
        if hasTaskMain || hasMain { return } // user-defined main

        emit("int main(int argc, char** argv) {")
        indentLevel += 1
        emit("plain_runtime_init(argc, argv);")
        // Emit top-level statements
        for decl in program.declarations {
            if case .statement(let s) = decl {
                emitStatement(s)
            }
        }
        emit("return 0;")
        indentLevel -= 1
        emit("}")
    }

    // MARK: — Type mapping

    private func cType(_ t: TypeAnnotation) -> String {
        switch t {
        case .named("text"):    return "plain_text_t"
        case .named("number"):  return "int64_t"
        case .named("decimal"): return "double"
        case .named("bool"):    return "int"
        case .named("nothing"): return "void*"
        case .named("path"):    return "plain_path_t"
        case .named("moment"):  return "plain_moment_t"
        case .named("response"):return "plain_response_t*"
        case .named("json"):    return "plain_json_t*"
        case .named(let n):     return "plain_\(n)_t*"
        case .listOf:           return "plain_list_t"
        case .mapOf:            return "plain_map_t"
        case .channelOf:        return "plain_channel_t*"
        case .optional(let t):  return cType(t) + "_opt"
        case .sendChannel:      return "plain_channel_t*"
        case .receiveChannel:   return "plain_channel_t*"
        }
    }

    // MARK: — Output helpers

    private mutating func emit(_ line: String) {
        let prefix = String(repeating: indent, count: indentLevel)
        output += prefix + line + "\n"
    }

    private func escaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\t", with: "\\t")
    }
}
