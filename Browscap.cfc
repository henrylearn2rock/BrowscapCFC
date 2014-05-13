/** Detect browser capabilities from user agent string from CGI using `browscap.ini`.
	Download latest `browscap.ini` at http://browsers.garykeith.com/
 */
component
{
	/** parsed browser capabilities from ini */
	property struct browserCaps;

	/** number of records of browser capabilities */
	property numeric browserCapsCount; 
	
	/** sorted from longest to shortest */
	property array agentStringPatterns; 
	
	/** parallel array of agentStringPatterns, but turned into RegEX */
	property array agentRegexs; 
	
	
	/**
		@iniFilePath absolute path to `browscap.ini`
	*/
	function init(string iniFilePath="#expandPath('./browscap.ini')#")
	{
		variables.browserCaps = iniToStruct(iniFilePath);
		
		variables.browserCapsCount = structCount(browserCaps); 

		variables.agentStringPatterns = sortArrayByLen(structKeyArray(browserCaps), "desc");

		variables.agentRegexs = convertPatternToRegex(agentStringPatterns);
		
		return this;
	}
	
	
	private struct function iniToStruct(required string iniFilePath)
	{
		var data = {};
		var file = fileOpen(iniFilePath);

		while (!fileIsEOF(file))
		{
			var line = FileReadLine(file);
			var lineLen = len(line); 
			
			if (lineLen > 0)
			{
				switch (left(line, 1))
				{
					case ";" :
						continue;
					break;
					
					case "[" :
						section = mid(line, 2, lineLen - 2); 
					break;
					
					default:
						data[section][listFirst(line, "=")] = listRest(line, "=");  
				}
			}
		}
		
		fileClose(file);			
		return data;
	}
	
	
	private array function convertPatternToRegex(required array agentStringPatterns)
	{
		for (var i = 1; i <= arrayLen(agentStringPatterns); i++)
		{
			var regex = left(agentStringPatterns[i], 1) != "*" ? "^" : "";
			
			regex &= replaceList(agentStringPatterns[i], ".,*,?,(,),[,],+", "\.,.*,.,\(,\),\[,\],\+");
			
			if (right(agentStringPatterns[i], 1) != "*")
				regex &= "$";
			
			agentStringPatterns[i] = regex;
		}
		
		return agentStringPatterns;
	}
	
	
	/**
		@order ['asc'],'desc'
	*/
	private array function sortArrayByLen(required array strings, string order="asc")
	{
		for (var i = 1; i <= arrayLen(strings); i++)
			local.lengths[i] = len(strings[i]);
		
		var sortedIndices = structSort(lengths, "numeric", order);
		var results = [];
		
		for (var index in sortedIndices)
			arrayAppend(results, strings[index]);
		
		return results;
	}
	
	
	/** @userAgent defaults to `CGI.HTTP_USER_AGENT` */
	function getBrowser(string userAgent=CGI.HTTP_USER_AGENT)
	{
		// find the longest matched agent, since agent is sorted by len desc, first agent is sufficient 
		var matchedIndex = 1;
		while (matchedIndex < variables.browserCapsCount 
				&& !reFindNoCase(variables.agentRegexs[matchedIndex], userAgent))
			++matchedIndex;
			
		var matchedStringPattern = agentStringPatterns[matchedIndex];
		var result = {};
		
		structAppend(result, browserCaps[matchedStringPattern]);

		// Fetch the rest of the info from parent(s)
		while (structKeyExists(result, "parent"))
		{
			var parentAgent = result.parent;
			structDelete(result, "parent");
			structAppend(result, browserCaps[parentAgent], false);
		}
		
		return result;
	}
	
}
