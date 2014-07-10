
module dabble.meta;

import 
	std.stdio, 
	std.conv;
 
import 
	dabble.repl,
	dabble.grammars;

	
/**
* See if the given buffer contains meta commands, which are interpreted directly
* and do not trigger recompilation.
*/
bool handleMetaCommand(ref string inputBuffer, ref string codeBuffer,ref Tuple!(string,Stage) res)
{
    import std.conv : text;
    import std.process : system;
    import std.string : join;
    import std.algorithm : canFind, map, find, splitter;
    import std.range : array, front, empty;

	// why use pegged a string switch is enough!

    alias T = Tuple!(string, Operation[]);
	string cmd = inputBuffer.splitter(" ").array[0];
	string[] args = inputBuffer.splitter(" ").array[1 .. $];
    /** Value print helper **/
    string printValue(T p)
    {
        auto v = context.share.vars.find!((a,b) => a.name == b)(p[0]);
        if (v.empty) return "";
        return  v.front.ty !is null ?
            v.front.ty.valueOf(p[1], v.front.addr, context.share.map) :
                v.front.func ? v.front.init : "";
    }

    /** Type print helper **/
    string printType(T p)
    {
        auto v = context.share.vars.find!((a,b) => a.name == b)(p[0]);
        if (v.empty) return "";
        if (v.front.ty is null) return v.front.displayType;
        auto t = v.front.ty.typeOf(p[1], context.share.map);
        return t[1].length ? t[1] : t[0].toString();
    }
	string summary, jsonstr;
	res[1] = Stage.meta; 
    switch(cmd)
    {
        case "version":
        {
			summary = title();
			jsonstr = json("id","meta","cmd","version","summary",title());
			break;
        }
		case "history": // return raw code, history of d code in this session
        {
			summary = context.rawCode.toString();			
			jsonstr = json("id", "meta", "cmd", "history", "summary", summary.escapeJSON());
			break;
        }
        case "print": with(context.share)
        {
            if (args.length == 0 || canFind(args, "all")) // print all vars
			{
				summary = vars.map!(v => text(v.name, " (", v.displayType, ") = ", printValue(T(v.name,[])))).join("\n");
				jsonstr = json("id", "meta", "cmd", "print", "summary", summary.escapeJSON(), "data", 
							vars.map!(v => tuple("name", v.name, "type", v.displayType.escapeJSON(), "value", printValue(T(v.name,[])).escapeJSON())).array);
			}
            else if (args.length == 1 && args[0] == "__keepAlive")
			{
				summary = "SharedLibs still alive:" ~ .keepAlive.map!(a => a.to!string()).join("\n");
				jsonstr = json("id", "meta", "cmd", "__keepAlive", "summary", summary.escapeJSON(), "data", .keepAlive.map!(a => a.to!string()).array);
			}
            else // print selected symbols
			{
				summary = args.map!(a => printValue(parseExpr(a))).join("\n");
				jsonstr = json("id", "meta", "cmd", "print", "summary", summary.escapeJSON(), "data", args.map!(a => printValue(parseExpr(a)).escapeJSON()).array);
			}
			break;
        }
        case "type": with(context.share)
        {
            if (args.length == 0 || canFind(args, "all")) // print types of all vars
			{
				summary = vars.map!(v => text(v.name, " ") ~ printType(T(v.name,[]))).join("\n");
				jsonstr = json("id", "meta", "cmd", "type", "summary", summary.escapeJSON(), "data", 
							vars.map!(v => tuple("name", v.name, "type", printType(T(v.name,[])).escapeJSON())).array);
			}
            else
			{
				summary = args.map!(a => printType(parseExpr(a))).join("\n");
				jsonstr = json("id", "meta", "cmd", "type", "summary", summary.escapeJSON(), "data", args.map!(a => printType(parseExpr(a)).escapeJSON()).array);
			}
			break;
        }
        case "reset":
        {
            if (canFind(args, "session"))
            {
                context.reset();
                keepAlive.clear();
				summary = "Session reset";
				jsonstr = json("id", "meta", "cmd", "reset session", "summary", "Session reset");
            }
            break;
        }
        case "delete":
        {
            foreach(a; args)
                context.share.deleteVar(a);
            break;
        }
        case "use":
        {
            import std.file : exists;
            import std.range : ElementType;
            import std.path : dirName, baseName, dirSeparator;
            import std.datetime : SysTime;
            alias ElementType!(typeof(context.userModules)) TupType;

			string[] msg;
            foreach(a; args)
            {
                if (exists(a))
				{
                    context.userModules ~= TupType(dirName(a), baseName(a), SysTime(0).stdTime());
					continue;
				}
				
				// see if the file exists in dabble src directory (like delve.d does)
				auto altPath = [replPath(), "src", "dabble", a].join(dirSeparator);
				if (exists(altPath))
				{
					context.userModules ~= TupType(dirName(altPath), baseName(altPath), SysTime(0).stdTime());
					continue;					
				}
                
				// else fail
				msg ~= text("Error: module ", a, " could not be found");
            }

			summary = msg.join("\n");
			jsonstr = json("id", "meta", "cmd", "use", "summary", summary.escapeJSON(), "data", msg);
			break;
        }
        case "clear":
        {
            if (args.length == 0)
			{}// clearScreen();
            else if (args.length == 1 && args[0] == "buffer")
                codeBuffer.clear();
            break;
        }
        case "debug" :
			if (args[0] == "on") {
			foreach(arg; args[1..$])
				setDebugLevelFromString!"on"(arg);
			} else if (args[0] == "off") {
				foreach(arg; args[1..$])
				setDebugLevelFromString!"off"(arg);
			} else 
				return false;
			break;
		case "help" :
				summary ~= text("help msg");
//				jsonstr = json("id", "meta", "cmd", "help", "summary", summary.escapeJSON(), "data", msg);
			break;
		case "exit" : 
			res[1] = Stage.none;
			break;
		default:
			return false;

    }

	// If we got to here, we successfully parsed a meta command, so clear the code buffer
	consoleSession ? summary.send : jsonstr.send;
	codeBuffer.clear();
    return true;
}
