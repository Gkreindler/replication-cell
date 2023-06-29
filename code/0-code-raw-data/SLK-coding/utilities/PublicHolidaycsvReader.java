package utilities;


import java.io.FileNotFoundException;
import java.io.FileReader;
import java.util.HashMap;
import au.com.bytecode.opencsv.*;
import java.io.IOException;
import java.util.*;
//import au.com.bytecode.CSVReader;


/**
 * 
 * cellid	siteid	longitude	latitude	azimuth	max_cell_d	DSD_Code4	Province_N	District_N	DS_N
 * @author gabrielk
 *
 */

public class PublicHolidaycsvReader {
	private static PublicHolidaycsvReader DScsv = null;
	private String file = "/home/gabriel/Data/input/PublicHolidaysSimple.csv";
	public HashSet<Integer> dayset = new HashSet<Integer>();  //DS map 
	
	public PublicHolidaycsvReader() {
	
			CSVReader reader;
			try {
				reader = new CSVReader(new FileReader(file));			
				String[] nextLine;
				while ((nextLine = reader.readNext()) != null) {
					//System.out.println(nextLine[1]+" "+nextLine[13]);
					try {
						dayset.add( Integer.valueOf(nextLine[0]) );
					}
					catch (Exception e) {
						System.err.println("Problem" );
						System.err.println("Problem" );
					}
				}
			} catch (Exception e) {				
				System.out.println(e.getMessage());
			}
	}
	
	
		
}