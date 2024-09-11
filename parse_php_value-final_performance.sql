-- DROP FUNCTION public.parse_php_value(text);

CREATE OR REPLACE FUNCTION public.parse_php_value(php_str text)
 RETURNS text
LANGUAGE plpgsql
IMMUTABLE 
PARALLEL SAFE
COST 500
AS $function$

DECLARE
    array_size INTEGER;
    result TEXT;
    temp_array TEXT[];
    key_item TEXT;
    value_item TEXT;
	prefix TEXT;
	i INTEGER;
	j INTEGER;
BEGIN


    -- Identifikujeme prefix pro typ dat
    -- temp_array := regexp_match(php_str, '^([abdisN]):(.*)');
	temp_array[1] := substring(php_str FROM 1 FOR 1);
	temp_array[2] := substring(php_str FROM 3); -- začne na třetím znaku po prefixu a ':'
	-- RAISE NOTICE 'parse_php_value: *** START temp1=% temp2=%', temp_array[1],temp_array[2];

    -- Kontrola prefixu a zpracování dle typu
    CASE temp_array[1]
        WHEN 'i', 'd', 'b' THEN
            result := temp_array[2];

        WHEN 's' THEN
            -- Řetězec
            -- temp_array := regexp_match(temp_array[2], '^(\d+):"(.*)"');
		i := strpos(temp_array[2], ':');
        	array_size := substring(temp_array[2] FROM 1 FOR (i - 1))::integer;
        	temp_array[2] := substring(temp_array[2] FROM (i + 2) FOR (length(temp_array[2]) - (i + 2)));
            	result := '"' || temp_array[2] || '"';
			-- RAISE NOTICE 'parse_php_value: case type=string line=1 temp1=% temp2=%', temp_array[1],temp_array[2]; 

        WHEN 'a' THEN
            -- Pole (array)
            
            result :='';
			
			-- Vyjmutí počtu prvků v poli
			-- temp_array := regexp_match(temp_array[2], '^(\d+):\{(.+)');
            		-- array_size := CAST(temp_array[1] AS INTEGER);

			i := strpos(temp_array[2], ':');
        		-- array_size := substring(temp_array[2] FROM 1 FOR (i - 1))::integer;
			array_size := CAST(substring(temp_array[2] FROM 1 FOR (i - 1)) as INTEGER);
        		temp_array[2] := substring(temp_array[2] FROM (i + 2));

			-- RAISE NOTICE 'parse_php_value: case type=array line=1 size=% temp1=% temp2=%', array_size, temp_array[1],temp_array[2]; 
            -- Zpracování každého prvku pole
            FOR i IN 1..array_size LOOP

                	-- Vyjmutí klíče a hodnoty
                		-- temp_array := regexp_match(temp_array[2], '([^;]+);(.+)');
			-- Rozdělíme klíč a hodnotu pole
				j := strpos(temp_array[2], ';');
    				temp_array[1] := substring(temp_array[2] FROM 1 FOR (j - 1));
    				temp_array[2] := substring(temp_array[2] FROM (j + 1));

  				-- RAISE NOTICE 'parse_php_value: loop line=1a iterace=% temp1=% temp2=%', i, temp_array[1],temp_array[2]; 

				-- Extrakce klíče pole
  		        	key_item := parse_php_value(temp_array[1]);

                		-- Extrakce hodnoty pole podle typu hodnoty
				prefix := substring(temp_array[2] FROM 1 FOR 1);
				CASE prefix
      				WHEN 'i', 'd', 'b' THEN
						-- Extrakce hodnoty pole
						-- temp_array := regexp_match(temp_array[2],'(^[idb][^;]+);(.*)$');
						j := strpos(temp_array[2], ';');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (j - 1));
    					temp_array[2] := substring(temp_array[2] FROM (j + 1));
						value_item := parse_php_value(temp_array[1]);
						-- Aktualizace výsledku
						result := result || key_item || ': ' || value_item;
					WHEN 's' THEN
						-- Extrakce hodnoty pole
						-- s:23:"01234567890123456789123";i:2;
						-- temp_array := regexp_match(temp_array[2],'(^s[^;}]+\");(.*)$');
						j := strpos(temp_array[2], '";');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (j + 0)); -- vcetne paternu
    					temp_array[2] := substring(temp_array[2] FROM (j + 2)); -- preskocit pattern
						-- Aktualizace výsledku
						value_item := parse_php_value(temp_array[1]);
						result := result || key_item || ': ' || value_item;
					WHEN 'a' THEN
						-- Extrakce hodnoty pole
						-- temp_array := regexp_match(temp_array[2],'(^a[^\}]+;)\}(.*)$');
						j := strpos(temp_array[2], ';}');
    					temp_array[1] := substring(temp_array[2] FROM 1 FOR (j + 0)); -- vcetne paternu
    					temp_array[2] := substring(temp_array[2] FROM (j + 2)); -- preskocit pattern
						value_item := parse_php_value(temp_array[1]);
						-- Aktualizace výsledku
						result := result || '"' || key_item || '": ' || value_item;
					WHEN 'N' THEN
						-- Extrakce hodnoty pole
						temp_array := regexp_match(temp_array[2],'(^N);(.*)$');
						value_item := parse_php_value(temp_array[1]);
						-- Aktualizace výsledku
						result := result || key_item || ': ' || value_item;
				END CASE;

		/*
                RAISE NOTICE 'parse_php_value: loop line=1b iterace=% temp1=% temp2=%', i, temp_array[1],temp_array[2]; 
				RAISE NOTICE 'parse_php_value: loop line=2 iterace=% key_item=% value_item=%', i,key_item,value_item; 
		*/
                		-- Formatovani výsledku
				if i != array_size then
					result := result || ', ';
				end if;
 
            END LOOP;
			-- Finalizace výsledku
			result := '{' || result || '}';
			-- RAISE NOTICE 'parse_php_value: loop line=3 result=%', result; 

        WHEN 'N' THEN
            result := 'null';

        ELSE
            -- RAISE NOTICE 'parse_php_value: Uknown prefix: %', temp_array[1];
            result := 'null';
    END CASE;

	-- RAISE NOTICE 'parse_php_value: *** END result=%', result;
    RETURN result;
END;
 $function$
;


