-- DROP FUNCTION public.parse_php_value(text);

CREATE OR REPLACE FUNCTION public.parse_php_value(php_str text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE PARALLEL SAFE COST 500
AS $function$

DECLARE
    array_size INTEGER;
    
    temp_array TEXT[];
    key_item TEXT;
    value_item TEXT;
	prefix TEXT;
	result TEXT;

	i INTEGER;
	j INTEGER;
BEGIN

    -- Identify of prefix for data type in PHP structure.

    -- Slow code: temp_array := regexp_match(php_str, '^([abdisN]):(.*)');
	temp_array[1] := substring(php_str FROM 1 FOR 1);
	temp_array[2] := substring(php_str FROM 3); -- začne na třetím znaku po prefixu a ':'

	-- Debuging
	-- RAISE NOTICE 'parse_php_value: *** START temp1=% temp2=%', temp_array[1],temp_array[2];

    -- Check of prefix and operate by data type PHP structure.
    CASE temp_array[1]
        WHEN 'i', 'd', 'b' THEN
			-- Example: i:1
            result := temp_array[2];

        WHEN 's' THEN
            -- Detected of string
            -- Slow code: temp_array := regexp_match(temp_array[2], '^(\d+):"(.*)"');
			i := strpos(temp_array[2], ':');
        	array_size := CAST(substring(temp_array[2] FROM 1 FOR (i - 1)) as INTEGER);
        	temp_array[2] := substring(temp_array[2] FROM (i + 2) FOR (array_size));
			-- Slow code: temp_array[2] := substring(temp_array[2] FROM (i + 2) FOR (length(temp_array[2]) - (i + 2)));

            result := '"' || temp_array[2] || '"';

			-- Debuging
			-- RAISE NOTICE 'parse_php_value: case type=string line=1 position=% array_size=% temp1=% temp2=%', i, array_size, temp_array[1],temp_array[2]; 

        WHEN 'a' THEN
            -- Detected of array
            -- Clear of result.
			-- Example: 'a:1:{i:0;a:5:{s:6:"poradi";i:1;s:3:"ais";s:5:"2.155";s:4:"issn";s:9:"2399-5300";s:7:"kvartil";s:2:"Q4";s:5:"decil";s:0:"";}}'
            result :='';
			
			-- Extract of members count at array.

			-- temp_array := regexp_match(temp_array[2], '^(\d+):\{(.+)');
            -- array_size := CAST(temp_array[1] AS INTEGER);
			i := strpos(temp_array[2], ':');

        	-- No SQL standard code: array_size := substring(temp_array[2] FROM 1 FOR (i - 1))::integer;
			array_size := CAST(substring(temp_array[2] FROM 1 FOR (i - 1)) as INTEGER);
        	temp_array[2] := substring(temp_array[2] FROM (i + 2));

			-- Debuging
			-- RAISE NOTICE 'parse_php_value: case type=array line=1 size=% temp1=% temp2=%', array_size, temp_array[1],temp_array[2]; 
            -- Zpracování každého prvku pole
            FOR j IN 1..array_size LOOP

                -- Get of Key and Value. 

                
				-- Split Key and Value of Array by delimiter ";".
				-- Slow code: temp_array := regexp_match(temp_array[2], '([^;]+);(.+)');
				i := strpos(temp_array[2], ';');
    			temp_array[1] := substring(temp_array[2] FROM 1 FOR (i - 1)); -- without of pattern
    			temp_array[2] := substring(temp_array[2] FROM (i + 1)); -- jump of pattern

				-- Debuging
  				-- RAISE NOTICE 'parse_php_value: loop line=1a iterace=% temp1=% temp2=%', j, temp_array[1],temp_array[2]; 

				-- Get of key of array.
  		        key_item := parse_php_value(temp_array[1]);

                -- Get of Value of Array by Value type.
				prefix := substring(temp_array[2] FROM 1 FOR 1);
				CASE prefix
      				WHEN 'i', 'd', 'b' THEN
						-- Get of Value

						-- Slow code: temp_array := regexp_match(temp_array[2],'(^[idb][^;]+);(.*)$');
						i := strpos(temp_array[2], ';');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (i - 1)); -- without of pattern
    					temp_array[2] := substring(temp_array[2] FROM (i + 1)); -- jump of pattern
						value_item := parse_php_value(temp_array[1]);

						-- Actualization of result
						result := result || key_item || ': ' || value_item;

					WHEN 's' THEN
						-- Get of Value

						-- Example: s:23:"01234567890123456789123";i:2;
						-- Slow code: temp_array := regexp_match(temp_array[2],'(^s[^;}]+\");(.*)$');
						i := strpos(temp_array[2], '";');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (i + 0)); -- include of pattern
    					temp_array[2] := substring(temp_array[2] FROM (i + 2)); -- jump of pattern
						value_item := parse_php_value(temp_array[1]);

						-- Actualization of result
						result := result || key_item || ': ' || value_item;

					WHEN 'a' THEN
						-- Extrakce hodnoty pole
						-- Slow code: temp_array := regexp_match(temp_array[2],'(^a[^\}]+;)\}(.*)$');
						i := strpos(temp_array[2], ';}');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (i + 0)); -- include of pattern
    					temp_array[2] := substring(temp_array[2] FROM (i + 2)); -- jump of pattern
						value_item := parse_php_value(temp_array[1]);

						-- Actualization of result
						result := result || '"' || key_item || '": ' || value_item;

					WHEN 'N' THEN
						-- Extrakce hodnoty pole
						temp_array := regexp_match(temp_array[2],'(^N);(.*)$');
						value_item := parse_php_value(temp_array[1]);

						-- Actualization of result
						result := result || key_item || ': ' || value_item;
				END CASE;

		/*
				-- Debuging results
                RAISE NOTICE 'parse_php_value: loop line=1b iterace=% temp1=% temp2=%', j, temp_array[1],temp_array[2]; 
				RAISE NOTICE 'parse_php_value: loop line=2 iterace=% key_item=% value_item=%', j,key_item,value_item; 
		*/
                -- Formating of result
				if j != array_size then
					result := result || ', ';
				end if;
 
            END LOOP;
			-- Finalize of result
			-- format('{ %s }', result);
			result := '{' || result || '}';
			-- Debuging results			
			-- RAISE NOTICE 'parse_php_value: loop line=3 result=%', result; 

        WHEN 'N' THEN
            result := 'null';

        ELSE
			-- Debuging	
            -- RAISE NOTICE 'parse_php_value: Uknown prefix: %', temp_array[1];
            result := 'null';
    END CASE;
	-- Debuging	
	-- RAISE NOTICE 'parse_php_value: *** END result=%', result;
    RETURN result;
END;
 $function$
;
