// Written in the D programming language

/**
 * $(H2 Summary)
 * This module contains a range-based _lexer generator.
 *
 * $(H2 Overview)
 * The _lexer generator consists of a template mixin, $(LREF Lexer), along with
 * several helper templates for generating such things as token identifiers.
 *
 * To write a _lexer using this API:
 * $(OL
 *     $(LI Create the string array costants for your language.
 *         $(UL
 *             $(LI $(LINK2 #.StringConstants, String Constants))
 *         ))
 *     $(LI Create aliases for the various token and token identifier types
 *         specific to your language.
 *         $(UL
 *             $(LI $(LREF TokenIdType))
 *             $(LI $(LREF tokenStringRepresentation))
 *             $(LI $(LREF TokenStructure))
 *             $(LI $(LREF TokenId))
 *         ))
 *     $(LI Create a struct that mixes in the Lexer template mixin and
 *         implements the necessary functions.
 *         $(UL
 *             $(LI $(LREF Lexer))
 *         ))
 * )
 * Examples:
 * $(UL
 * $(LI A _lexer for D is available $(LINK2 https://github.com/Hackerpilot/Dscanner/blob/master/stdx/d/lexer.d, here).)
 * $(LI A _lexer for Lua is available $(LINK2 https://github.com/Hackerpilot/lexer-demo/blob/master/lualexer.d, here).)
 * )
 * $(DDOC_ANCHOR StringConstants) $(H2 String Constants)
 * $(DL
 * $(DT $(B staticTokens))
 * $(DD A listing of the tokens whose exact value never changes and which cannot
 *     possibly be a token handled by the default token lexing function. The
 *     most common example of this kind of token is an operator such as
 *     $(D_STRING "*"), or $(D_STRING "-") in a programming language.)
 * $(DT $(B dynamicTokens))
 * $(DD A listing of tokens whose value is variable, such as whitespace,
 *     identifiers, number literals, and string literals.)
 * $(DT $(B possibleDefaultTokens))
 * $(DD A listing of tokens that could posibly be one of the tokens handled by
 *     the default token handling function. An common example of this is
 *     a keyword such as $(D_STRING "for"), which looks like the beginning of
 *     the identifier $(D_STRING "fortunate"). isSeparating is called to
 *     determine if the character after the $(D_STRING 'r') separates the
 *     identifier, indicating that the token is $(D_STRING "for"), or if lexing
 *     should be turned over to the defaultTokenFunction.)
 * $(DT $(B tokenHandlers))
 * $(DD A mapping of prefixes to custom token handling function names. The
 *     generated _lexer will search for the even-index elements of this array,
 *     and then call the function whose name is the element immedately after the
 *     even-indexed element. This is used for lexing complex tokens whose prefix
 *     is fixed.)
 * )
 *
 * Here are some example constants for a simple calculator _lexer:
 * ---
 * // There are a near infinite number of valid number literals, so numbers are
 * // dynamic tokens.
 * enum string[] dynamicTokens = ["numberLiteral", "whitespace"];
 *
 * // The operators are always the same, and cannot start a numberLiteral, so
 * // they are staticTokens
 * enum string[] staticTokens = ["-", "+", "*", "/"];
 *
 * // In this simple example there are no keywords or other tokens that could
 * // look like dynamic tokens, so this is blank.
 * enum string[] possibleDefaultTokens = [];
 *
 * // If any whitespace character or digit is encountered, pass lexing over to
 * // our custom handler functions. These will be demonstrated in an example
 * // later on.
 * enum string[] tokenHandlers = [
 *     "0", "lexNumber",
 *     "1", "lexNumber",
 *     "2", "lexNumber",
 *     "3", "lexNumber",
 *     "4", "lexNumber",
 *     "5", "lexNumber",
 *     "6", "lexNumber",
 *     "7", "lexNumber",
 *     "8", "lexNumber",
 *     "9", "lexNumber",
 *     " ", "lexWhitespace",
 *     "\n", "lexWhitespace",
 *     "\t", "lexWhitespace",
 *     "\r", "lexWhitespace"
 * ];
 * ---
 *
 * Copyright: Brian Schott 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt Boost, License 1.0)
 * Authors: Brian Schott, with ideas shamelessly stolen from Andrei Alexandrescu
 * Source: $(PHOBOSSRC std/_lexer.d)
 */

module stdx.lexer;

/**
 * Template for determining the type used for a token type. Selects the smallest
 * unsigned integral type that is able to hold the value
 * staticTokens.length + dynamicTokens.length. For example if there are 20
 * static tokens, 30 dynamic tokens, and 10 possible default tokens, this
 * template will alias itself to ubyte, as 20 + 30 + 10 < $(D_KEYWORD ubyte).max.
 * Examples:
 * ---
 * // In our calculator example this means that IdType is an alias for ubyte.
 * alias IdType = TokenIdType!(staticTokens, dynamicTokens, possibleDefaultTokens);
 * ---
 */
template TokenIdType(alias staticTokens, alias dynamicTokens,
	alias possibleDefaultTokens)
{
  static if ((staticTokens.length + dynamicTokens.length + possibleDefaultTokens.length) <= ubyte.max)
		alias TokenIdType = ubyte;
	else static if ((staticTokens.length + dynamicTokens.length + possibleDefaultTokens.length) <= ushort.max)
		alias TokenIdType = ushort;
	else static if ((staticTokens.length + dynamicTokens.length + possibleDefaultTokens.length) <= uint.max)
		alias TokenIdType = uint;
	else
		static assert (false);
}

/**
 * Looks up the string representation of the given token type. This is the
 * opposite of the function of the TokenId template.
 * Params: type = the token type identifier
 * Examples:
 * ---
 * alias str = tokenStringRepresentation(IdType, staticTokens, dynamicTokens, possibleDefaultTokens);
 * assert (str(tok!"*") == "*");
 * ---
 * See_also: $(LREF TokenId)
 */
string tokenStringRepresentation(IdType, alias staticTokens, alias dynamicTokens, alias possibleDefaultTokens)(IdType type) @property
{
	if (type == 0)
		return "!ERROR!";
	else if (type < staticTokens.length + 1)
		return staticTokens[type - 1];
	else if (type < staticTokens.length + possibleDefaultTokens.length + 1)
		return possibleDefaultTokens[type - staticTokens.length - 1];
	else if (type < staticTokens.length + possibleDefaultTokens.length + dynamicTokens.length + 1)
		return dynamicTokens[type - staticTokens.length - possibleDefaultTokens.length - 1];
	else
		return null;
}

/**
 * Generates the token type identifier for the given symbol. There are two
 * special cases:
 * $(UL
 *     $(LI If symbol is "", then the token identifier will be 0)
 *     $(LI If symbol is "\0", then the token identifier will be the maximum
 *         valid token type identifier)
 * )
 * In all cases this template will alias itself to a constant of type IdType.
 * This template will fail at compile time if $(D_PARAM symbol) is not one of
 * the staticTokens, dynamicTokens, or possibleDefaultTokens.
 * Examples:
 * ---
 * template tok(string symbol)
 * {
 *     alias tok = TokenId!(IdType, staticTokens, dynamicTokens,
 *         possibleDefaultTokens, symbol);
 * }
 * // num and plus are of type ubyte.
 * IdType plus = tok!"+";
 * IdType num = tok!"numberLiteral";
 * ---
 */
template TokenId(IdType, alias staticTokens, alias dynamicTokens,
	alias possibleDefaultTokens, string symbol)
{
	import std.algorithm;
	static if (symbol == "")
	{
		enum id = 0;
		alias TokenId = id;
	}
	else static if (symbol == "\0")
	{
		enum id = 1 + staticTokens.length + dynamicTokens.length + possibleDefaultTokens.length;
		alias TokenId = id;
	}
	else
	{
		enum i = staticTokens.countUntil(symbol);
		static if (i >= 0)
		{
			enum id = i + 1;
			alias TokenId = id;
		}
		else
		{
			enum ii = possibleDefaultTokens.countUntil(symbol);
			static if (ii >= 0)
			{
				enum id = ii + staticTokens.length + 1;
				static assert (id >= 0 && id < IdType.max, "Invalid token: " ~ symbol);
				alias TokenId = id;
			}
			else
			{
				enum dynamicId = dynamicTokens.countUntil(symbol);
				enum id = dynamicId >= 0
					? i + staticTokens.length + possibleDefaultTokens.length + dynamicId + 1
					: -1;
				static assert (id >= 0 && id < IdType.max, "Invalid token: " ~ symbol);
				alias TokenId = id;
			}
		}
	}
}

/**
 * The token that is returned by the lexer.
 * Params:
 *     IdType = The D type of the "type" token type field.
 *     extraFields = A string containing D code for any extra fields that should
 *         be included in the token structure body. This string is passed
 *         directly to a mixin statement.
 * Examples:
 * ---
 * // No extra struct fields are desired in this example, so leave it blank.
 * alias Token = TokenStructure!(IdType, "");
 * Token minusToken = Token(tok!"-");
 * ---
 */
struct TokenStructure(IdType, string extraFields = "")
{
public:

	/**
	 * == overload for the the token type.
	 */
	bool opEquals(IdType type) const pure nothrow @safe
	{
		return this.type == type;
	}

	/**
	 * Constructs a token from a token type.
	 * Params: type = the token type
	 */
	this(IdType type)
	{
		this.type = type;
	}

	/**
	 * Constructs a token.
	 * Params:
	 *     type = the token type
	 *     text = the text of the token, which may be null
	 *     line = the line number at which this token occurs
	 *     column = the column nmuber at which this token occurs
	 *     index = the byte offset from the beginning of the input at which this
	 *         token occurs
	 */
	this(IdType type, string text, size_t line, size_t column, size_t index)
	{
		this.text = text;
		this.line = line;
		this.column = column;
		this.type = type;
		this.index = index;
	}

	/**
	 * The _text of the token.
	 */
	string text;

	/**
	 * The line number at which this token occurs.
	 */
	size_t line;

	/**
	 * The Column nmuber at which this token occurs.
	 */
	size_t column;

	/**
	 * The byte offset from the beginning of the input at which this token
	 * occurs.
	 */
	size_t index;

	/**
	 * The token type.
	 */
	IdType type;

	mixin (extraFields);
}

/**
 * The implementation of the _lexer is contained within this mixin template.
 * To use it, this template should be mixed in to a struct that represents the
 * _lexer for your language. This struct should implement the following methods:
 * $(UL
 *     $(LI popFront, which should call this mixin's _popFront() and
 *         additionally perform any token filtering or shuffling you deem
 *         necessary. For example, you can implement popFront to skip comment or
 *          tokens.)
 *     $(LI A function that serves as the default token lexing function. For
 *         most languages this will be the identifier lexing function.)
 *     $(LI A function that is able to determine if an identifier/keyword has
 *         come to an end. This function must retorn $(D_KEYWORD bool) and take
 *         a single $(D_KEYWORD size_t) argument representing the number of
 *         bytes to skip over before looking for a separating character.)
 *     $(LI Any functions referred to in the tokenHandlers template paramater.
 *         These functions must be marked $(D_KEYWORD pure nothrow), take no
 *         arguments, and return a token)
 *     $(LI A constructor that initializes the range field as well as calls
 *         popFront() exactly once (to initialize the _front field).)
 * )
 * Examples:
 * ---
 * struct CalculatorLexer
 * {
 *     mixin Lexer!(IdType, Token, defaultTokenFunction, isSeparating,
 *         staticTokens, dynamicTokens, tokenHandlers, possibleDefaultTokens);
 *
 *     this (ubyte[] bytes)
 *     {
 *         this.range = LexerRange(bytes);
 *         popFront();
 *     }
 *
 *     void popFront() pure
 *     {
 *         _popFront();
 *     }
 *
 *     Token lexNumber() pure nothrow @safe
 *     {
 *         ...
 *     }
 *
 *     Token lexWhitespace() pure nothrow @safe
 *     {
 *         ...
 *     }
 *
 *     Token defaultTokenFunction() pure nothrow @safe
 *     {
 *         // There is no default token in the example calculator language, so
 *         // this is always an error.
 *         range.popFront();
 *         return Token(tok!"");
 *     }
 *
 *     bool isSeparating(size_t offset) pure nothrow @safe
 *     {
 *         // For this example language, always return true.
 *         return true;
 *     }
 * }
 * ---
 */
mixin template Lexer(IDType, Token, alias defaultTokenFunction,
	alias tokenSeparatingFunction, alias staticTokens, alias dynamicTokens,
	alias tokenHandlers, alias possibleDefaultTokens)
{

	static assert (tokenHandlers.length % 2 == 0, "Each pseudo-token must"
		~ " have a corresponding handler function name.");

	static string generateMask(const ubyte[] arr)
	{
		import std.string;
		ulong u;
		for (size_t i = 0; i < arr.length && i < 8; i++)
		{
			u |= (cast(ulong) arr[i]) << (i * 8);
		}
		return format("0x%016x", u);
	}

	static string generateByteMask(size_t l)
	{
		import std.string;
		return format("0x%016x", ulong.max >> ((8 - l) * 8));
	}

	static string generateCaseStatements()
	{
		import std.conv;
		import std.string;
		import std.range;

		string[] pseudoTokens = stupidToArray(tokenHandlers.stride(2));
		string[] allTokens = stupidToArray(sort(staticTokens ~ possibleDefaultTokens ~ pseudoTokens).uniq);
		string code;
		for (size_t i = 0; i < allTokens.length; i++)
		{
			size_t j = i + 1;
			size_t o = i;
			while (j < allTokens.length && allTokens[i][0] == allTokens[j][0]) j++;
			code ~= format("case 0x%02x:\n", cast(ubyte) allTokens[i][0]);
			code ~= printCase(allTokens[i .. j], pseudoTokens);
			i = j - 1;
		}
		return code;
	}

	static string printCase(string[] tokens, string[] pseudoTokens)
	{
		string[] t = tokens;
		string[] sortedTokens = stupidToArray(sort!"a.length > b.length"(t));
		import std.conv;

		if (tokens.length == 1 && tokens[0].length == 1)
		{
			if (pseudoTokens.countUntil(tokens[0]) >= 0)
			{
				return "    return "
					~ tokenHandlers[tokenHandlers.countUntil(tokens[0]) + 1]
					~ "();\n";
			}
			else if (staticTokens.countUntil(tokens[0]) >= 0)
			{
				return "    range.popFront();\n"
					~ "    return Token(tok!\"" ~ escape(tokens[0]) ~ "\", null, line, column, index);\n";
			}
			else if (pseudoTokens.countUntil(tokens[0]) >= 0)
			{
				return "    return "
					~ tokenHandlers[tokenHandlers.countUntil(tokens[0]) + 1]
					~ "();\n";
			}
		}

		string code;

		foreach (i, token; sortedTokens)
		{
			immutable mask = generateMask(cast (const ubyte[]) token);
			if (token.length >= 8)
				code ~= "    if (frontBytes == " ~ mask ~ ")\n";
			else
				code ~= "    if ((frontBytes & " ~ generateByteMask(token.length) ~ ") == " ~ mask ~ ")\n";
			code ~= "    {\n";
			if (pseudoTokens.countUntil(token) >= 0)
			{
				if (token.length <= 8)
				{
					code ~= "        return "
						~ tokenHandlers[tokenHandlers.countUntil(token) + 1]
						~ "();\n";
				}
				else
				{
					code ~= "        if (range.peek(" ~ text(token.length - 1) ~ ") == \"" ~ escape(token) ~"\")\n";
					code ~= "            return "
						~ tokenHandlers[tokenHandlers.countUntil(token) + 1]
						~ "();\n";
				}
			}
			else if (staticTokens.countUntil(token) >= 0)
			{
				if (token.length <= 8)
				{
					code ~= "        range.popFrontN(" ~ text(token.length) ~ ");\n";
					code ~= "        return Token(tok!\"" ~ escape(token) ~ "\", null, line, column, index);\n";
				}
				else
				{
					code ~= "        pragma(msg, \"long static tokens not supported\"); // " ~ escape(token) ~ "\n";
				}
			}
			else
			{
				// possible default
				if (token.length <= 8)
				{
					code ~= "        if (tokenSeparatingFunction(" ~ text(token.length) ~ "))\n";
					code ~= "        {\n";
					code ~= "            range.popFrontN(" ~ text(token.length) ~ ");\n";
					code ~= "            return Token(tok!\"" ~ escape(token) ~ "\", null, line, column, index);\n";
					code ~= "        }\n";
					code ~= "        else\n";
					code ~= "            goto default;\n";
				}
				else
				{
					code ~= "        if (range.peek(" ~ text(token.length - 1) ~ ") == \"" ~ escape(token) ~"\" && isSeparating(" ~ text(token.length) ~ "))\n";
					code ~= "        {\n";
					code ~= "            range.popFrontN(" ~ text(token.length) ~ ");\n";
					code ~= "            return Token(tok!\"" ~ escape(token) ~ "\", null, line, column, index);\n";
					code ~= "        }\n";
					code ~= "        else\n";
					code ~= "            goto default;\n";
				}
			}
			code ~= "    }\n";
		}
		code ~= "    else\n";
		code ~= "        goto default;\n";
		return code;
	}

	/**
	 * Implements the range primitive front().
	 */
	ref const(Token) front() pure nothrow const @property
	{
		return _front;
	}


	void _popFront() pure
	{
		_front = advance();
	}

	/**
	 * Implements the range primitive empty().
	 */
	bool empty() pure const nothrow @property
	{
		return _front.type == tok!"\0";
	}

	static string escape(string input)
	{
		string retVal;
		foreach (ubyte c; cast(ubyte[]) input)
		{
			switch (c)
			{
			case '\\': retVal ~= `\\`; break;
			case '"': retVal ~= `\"`; break;
			case '\'': retVal ~= `\'`; break;
			case '\t': retVal ~= `\t`; break;
			case '\n': retVal ~= `\n`; break;
			case '\r': retVal ~= `\r`; break;
			default: retVal ~= c; break;
			}
		}
		return retVal;
	}

	// This only exists because the real array() can't be called at compile-time
	static string[] stupidToArray(R)(R range)
	{
		string[] retVal;
		foreach (v; range)
			retVal ~= v;
		return retVal;
	}

	enum tokenSearch = generateCaseStatements();

	static ulong getFront(const ubyte[] arr) pure nothrow @trusted
	{
		import std.stdio;
		immutable importantBits = *(cast (ulong*) arr.ptr);
		immutable filler = ulong.max >> ((8 - arr.length) * 8);
		return importantBits & filler;
	}

	Token advance() pure
	{
		if (range.empty)
			return Token(tok!"\0");
		immutable size_t index = range.index;
		immutable size_t column = range.column;
		immutable size_t line = range.line;
		immutable ulong frontBytes = getFront(range.peek(7));
		switch (frontBytes & 0x00000000_000000ff)
		{
		mixin(tokenSearch);
//		pragma(msg, tokenSearch);
		default:
			return defaultTokenFunction();
		}
	}

	/**
	 * The lexer input.
	 */
	LexerRange range;

	/**
	 * The token that is currently at the front of the range.
	 */
	Token _front;
}

/**
 * Range structure that wraps the _lexer's input.
 */
struct LexerRange
{

	/**
	 * Params:
	 *     bytes = the _lexer input
	 *     index = the initial offset from the beginning of $(D_PARAM bytes)
	 *     column = the initial column number
	 *     line = the initial line number
	 */
	this(const(ubyte)[] bytes, size_t index = 0, size_t column = 1, size_t line = 1) pure nothrow @safe
	{
		this.bytes = bytes;
		this.index = index;
		this.column = column;
		this.line = line;
	}

	/**
	 * Returns: a mark at the current position that can then be used with slice.
	 */
	size_t mark() const nothrow pure @safe
	{
		return index;
	}

	/**
	 * Sets the range to the given position
	 * Params: m = the position to seek to
	 */
	void seek(size_t m) nothrow pure @safe
	{
		index = m;
	}

	/**
	 * Returs a slice of the input byte array betwene the given mark and the
	 * current position.
	 * Params m = the beginning index of the slice to return
	 */
	const(ubyte)[] slice(size_t m) const nothrow pure @safe
	{
		return bytes[m .. index];
	}

	/**
	 * Implements the range primitive _empty.
	 */
	bool empty() const nothrow pure @safe
	{
		return index >= bytes.length;
	}

	/**
	 * Implements the range primitive _front.
	 */
	ubyte front() const nothrow pure @safe
	{
		return bytes[index];
	}

	/**
	 * Returns: the current item as well as the items $(D_PARAM p) items ahead.
	 */
	const(ubyte)[] peek(size_t p) const nothrow pure @safe
	{
		return index + p + 1 > bytes.length
			? bytes[index .. $]
			: bytes[index .. index + p + 1];
	}

	/**
	 *
	 */
	ubyte peekAt(size_t offset) const nothrow pure @safe
	{
		return bytes[index + offset];
	}

	/**
	 * Returns: true if it is possible to peek $(D_PARAM p) bytes ahead.
	 */
	bool canPeek(size_t p) const nothrow pure @safe
	{
		return index + p < bytes.length;
	}

	/**
	 * Implements the range primitive _popFront.
	 */
	void popFront() pure nothrow @safe
	{
		index++;
		column++;
	}

	/**
	 * Implements the algorithm _popFrontN more efficiently.
	 */
	void popFrontN(size_t n) pure nothrow @safe
	{
		index += n;
		column += n;
	}

	/**
	 * Increments the range's line number and resets the column counter.
	 */
	void incrementLine() pure nothrow @safe
	{
		column = 1;
		line++;
	}

	/**
	 * The input _bytes.
	 */
	const(ubyte)[] bytes;

	/**
	 * The range's current position.
	 */
	size_t index;

	/**
	 * The current _column number.
	 */
	size_t column;

	/**
	 * The current _line number.
	 */
	size_t line;
}

/**
 * The string cache implements a map/set for strings. Placing a string in the
 * cache returns an identifier that can be used to instantly access the stored
 * string. It is then possible to simply compare these indexes instead of
 * performing full string comparisons when comparing the string content of
 * dynamic tokens. The string cache also handles its own memory, so that mutable
 * ubyte[] to lexers can still have immutable string fields in their tokens.
 * Because the string cache also performs de-duplication it is possible to
 * drastically reduce the memory usage of a lexer.
 */
struct StringCache
{
public:

	@disable this();

	/**
	 * Params: bucketCount = the initial number of buckets.
	 */
	this(size_t bucketCount)
	{
		buckets = new Item*[bucketCount];
	}

	/**
	 * Equivalent to calling cache() and get().
	 * ---
	 * StringCache cache;
	 * ubyte[] str = ['a', 'b', 'c'];
	 * string s = cache.get(cache.cache(str));
	 * assert(s == "abc");
	 * ---
	 */
	string cacheGet(const(ubyte[]) bytes) pure nothrow @safe
	{
		return get(cache(bytes));
	}

	/**
	 * Equivalent to calling cache() and get().
	 */
	string cacheGet(const(ubyte[]) bytes, uint hash) pure nothrow @safe
	{
		return get(cache(bytes, hash));
	}

	/**
	 * Caches a string.
	 * Params: bytes = the string to cache
	 * Returns: A key that can be used to retrieve the cached string
	 * Examples:
	 * ---
	 * StringCache cache;
	 * ubyte[] bytes = ['a', 'b', 'c'];
	 * size_t first = cache.cache(bytes);
	 * size_t second = cache.cache(bytes);
	 * assert (first == second);
	 * ---
	 */
	size_t cache(const(ubyte)[] bytes) pure nothrow @safe
	{
		immutable uint hash = hashBytes(bytes);
		return cache(bytes, hash);
	}

	/**
	 * Caches a string as above, but uses the given has code instead of
	 * calculating one itself. Use this alongside hashStep() can reduce the
	 * amount of work necessary when lexing dynamic tokens.
	 */
	size_t cache(const(ubyte)[] bytes, uint hash) pure nothrow @safe
	in
	{
		assert (bytes.length > 0);
	}
	out (retVal)
	{
		assert (retVal < items.length);
	}
	body
	{
		debug memoryRequested += bytes.length;
		const(Item)* found = find(bytes, hash);
		if (found is null)
			return intern(bytes, hash);
		return found.index;
	}

	/**
	 * Gets a cached string based on its key.
	 * Params: index = the key
	 * Returns: the cached string
	 */
	string get(size_t index) const pure nothrow @safe
	in
	{
		assert (items.length > index);
		assert (items[index] !is null);
	}
	out (retVal)
	{
		assert (retVal !is null);
	}
	body
	{
		return items[index].str;
	}

	debug void printStats()
	{
		import std.stdio;
		writeln("Load Factor:           ", cast(float) items.length / cast(float) buckets.length);
		writeln("Memory used by blocks: ", blocks.length * blockSize);
		writeln("Memory requsted:       ", memoryRequested);
		writeln("rehashes:              ", rehashCount);
	}

	/**
	 * Incremental hashing.
	 * Params:
	 *     b = the byte to add to the hash
	 *     h = the hash that has been calculated so far
	 * Returns: the new hash code for the string.
	 */
	static uint hashStep(ubyte b, uint h) pure nothrow @safe
	{
		return (h ^ sbox[b]) * 3;
	}

	/**
	 * The default bucket count for the string cache.
	 */
	static enum defaultBucketCount = 2048;

private:

	private void rehash() pure nothrow @safe
	{
		immutable size_t newBucketCount = items.length * 2;
		buckets = new Item*[newBucketCount];
		debug rehashCount++;
		foreach (item; items)
		{
			immutable size_t newIndex = item.hash % newBucketCount;
			item.next = buckets[newIndex];
			buckets[newIndex] = item;
		}
	}

	size_t intern(const(ubyte)[] bytes, uint hash) pure nothrow @trusted
	{
		ubyte[] mem = allocate(bytes.length);
		mem[] = bytes[];
		Item* item = cast(Item*) allocate(Item.sizeof).ptr;
		item.index = items.length;
		item.str = cast(string) mem;
		item.hash = hash;
		item.next = buckets[hash % buckets.length];
		immutable bool checkLoadFactor = item.next !is null;
		buckets[hash % buckets.length] = item;
		items ~= item;
		if (checkLoadFactor && (cast(float) items.length / cast(float) buckets.length) > 0.75)
			rehash();
		return item.index;
	}

	const(Item)* find(const(ubyte)[] bytes, uint hash) pure nothrow const @safe
	{
		import std.algorithm;
		immutable size_t index = hash % buckets.length;
		for (const(Item)* item = buckets[index]; item !is null; item = item.next)
		{
			if (item.hash == hash && bytes.equal(item.str))
				return item;
		}
		return null;
	}

	ubyte[] allocate(size_t byteCount) pure nothrow @trusted
	{
		import core.memory;
		if (byteCount > (blockSize / 4))
		{
			ubyte* mem = cast(ubyte*) GC.malloc(byteCount, GC.BlkAttr.NO_SCAN);
			return mem[0 .. byteCount];
		}
		foreach (ref block; blocks)
		{
			immutable size_t oldUsed = block.used;
			immutable size_t end = oldUsed + byteCount;
			if (end > block.bytes.length)
				continue;
			block.used = end;
			return block.bytes[oldUsed .. end];
		}
		blocks ~= Block(
			(cast(ubyte*) GC.malloc(blockSize, GC.BlkAttr.NO_SCAN))[0 .. blockSize],
			byteCount);
		return blocks[$ - 1].bytes[0 .. byteCount];
	}

	static uint hashBytes(const(ubyte)[] data) pure nothrow @safe
	{
		uint hash = 0;
		foreach (b; data)
		{
			hash ^= sbox[b];
			hash *= 3;
		}
		return hash;
	}

	static struct Item
	{
		size_t index;
		string str;
		uint hash;
		Item* next;
	}

	static struct Block
	{
		ubyte[] bytes;
		size_t used;
	}

	static enum blockSize = 1024 * 16;

	public static immutable uint[] sbox = [
		0xF53E1837, 0x5F14C86B, 0x9EE3964C, 0xFA796D53,
		0x32223FC3, 0x4D82BC98, 0xA0C7FA62, 0x63E2C982,
		0x24994A5B, 0x1ECE7BEE, 0x292B38EF, 0xD5CD4E56,
		0x514F4303, 0x7BE12B83, 0x7192F195, 0x82DC7300,
		0x084380B4, 0x480B55D3, 0x5F430471, 0x13F75991,
		0x3F9CF22C, 0x2FE0907A, 0xFD8E1E69, 0x7B1D5DE8,
		0xD575A85C, 0xAD01C50A, 0x7EE00737, 0x3CE981E8,
		0x0E447EFA, 0x23089DD6, 0xB59F149F, 0x13600EC7,
		0xE802C8E6, 0x670921E4, 0x7207EFF0, 0xE74761B0,
		0x69035234, 0xBFA40F19, 0xF63651A0, 0x29E64C26,
		0x1F98CCA7, 0xD957007E, 0xE71DDC75, 0x3E729595,
		0x7580B7CC, 0xD7FAF60B, 0x92484323, 0xA44113EB,
		0xE4CBDE08, 0x346827C9, 0x3CF32AFA, 0x0B29BCF1,
		0x6E29F7DF, 0xB01E71CB, 0x3BFBC0D1, 0x62EDC5B8,
		0xB7DE789A, 0xA4748EC9, 0xE17A4C4F, 0x67E5BD03,
		0xF3B33D1A, 0x97D8D3E9, 0x09121BC0, 0x347B2D2C,
		0x79A1913C, 0x504172DE, 0x7F1F8483, 0x13AC3CF6,
		0x7A2094DB, 0xC778FA12, 0xADF7469F, 0x21786B7B,
		0x71A445D0, 0xA8896C1B, 0x656F62FB, 0x83A059B3,
		0x972DFE6E, 0x4122000C, 0x97D9DA19, 0x17D5947B,
		0xB1AFFD0C, 0x6EF83B97, 0xAF7F780B, 0x4613138A,
		0x7C3E73A6, 0xCF15E03D, 0x41576322, 0x672DF292,
		0xB658588D, 0x33EBEFA9, 0x938CBF06, 0x06B67381,
		0x07F192C6, 0x2BDA5855, 0x348EE0E8, 0x19DBB6E3,
		0x3222184B, 0xB69D5DBA, 0x7E760B88, 0xAF4D8154,
		0x007A51AD, 0x35112500, 0xC9CD2D7D, 0x4F4FB761,
		0x694772E3, 0x694C8351, 0x4A7E3AF5, 0x67D65CE1,
		0x9287DE92, 0x2518DB3C, 0x8CB4EC06, 0xD154D38F,
		0xE19A26BB, 0x295EE439, 0xC50A1104, 0x2153C6A7,
		0x82366656, 0x0713BC2F, 0x6462215A, 0x21D9BFCE,
		0xBA8EACE6, 0xAE2DF4C1, 0x2A8D5E80, 0x3F7E52D1,
		0x29359399, 0xFEA1D19C, 0x18879313, 0x455AFA81,
		0xFADFE838, 0x62609838, 0xD1028839, 0x0736E92F,
		0x3BCA22A3, 0x1485B08A, 0x2DA7900B, 0x852C156D,
		0xE8F24803, 0x00078472, 0x13F0D332, 0x2ACFD0CF,
		0x5F747F5C, 0x87BB1E2F, 0xA7EFCB63, 0x23F432F0,
		0xE6CE7C5C, 0x1F954EF6, 0xB609C91B, 0x3B4571BF,
		0xEED17DC0, 0xE556CDA0, 0xA7846A8D, 0xFF105F94,
		0x52B7CCDE, 0x0E33E801, 0x664455EA, 0xF2C70414,
		0x73E7B486, 0x8F830661, 0x8B59E826, 0xBB8AEDCA,
		0xF3D70AB9, 0xD739F2B9, 0x4A04C34A, 0x88D0F089,
		0xE02191A2, 0xD89D9C78, 0x192C2749, 0xFC43A78F,
		0x0AAC88CB, 0x9438D42D, 0x9E280F7A, 0x36063802,
		0x38E8D018, 0x1C42A9CB, 0x92AAFF6C, 0xA24820C5,
		0x007F077F, 0xCE5BC543, 0x69668D58, 0x10D6FF74,
		0xBE00F621, 0x21300BBE, 0x2E9E8F46, 0x5ACEA629,
		0xFA1F86C7, 0x52F206B8, 0x3EDF1A75, 0x6DA8D843,
		0xCF719928, 0x73E3891F, 0xB4B95DD6, 0xB2A42D27,
		0xEDA20BBF, 0x1A58DBDF, 0xA449AD03, 0x6DDEF22B,
		0x900531E6, 0x3D3BFF35, 0x5B24ABA2, 0x472B3E4C,
		0x387F2D75, 0x4D8DBA36, 0x71CB5641, 0xE3473F3F,
		0xF6CD4B7F, 0xBF7D1428, 0x344B64D0, 0xC5CDFCB6,
		0xFE2E0182, 0x2C37A673, 0xDE4EB7A3, 0x63FDC933,
		0x01DC4063, 0x611F3571, 0xD167BFAF, 0x4496596F,
		0x3DEE0689, 0xD8704910, 0x7052A114, 0x068C9EC5,
		0x75D0E766, 0x4D54CC20, 0xB44ECDE2, 0x4ABC653E,
		0x2C550A21, 0x1A52C0DB, 0xCFED03D0, 0x119BAFE2,
		0x876A6133, 0xBC232088, 0x435BA1B2, 0xAE99BBFA,
		0xBB4F08E4, 0xA62B5F49, 0x1DA4B695, 0x336B84DE,
		0xDC813D31, 0x00C134FB, 0x397A98E6, 0x151F0E64,
		0xD9EB3E69, 0xD3C7DF60, 0xD2F2C336, 0x2DDD067B,
		0xBD122835, 0xB0B3BD3A, 0xB0D54E46, 0x8641F1E4,
		0xA0B38F96, 0x51D39199, 0x37A6AD75, 0xDF84EE41,
		0x3C034CBA, 0xACDA62FC, 0x11923B8B, 0x45EF170A,
	];

	Item*[] items;
	Item*[] buckets;
	Block[] blocks;
	debug size_t memoryRequested;
	debug uint rehashCount;
}
