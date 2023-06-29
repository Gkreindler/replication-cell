package utilities;


import java.io.*;
import java.util.HashMap;
import au.com.bytecode.opencsv.*;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;

import org.apache.hadoop.fs.FSDataInputStream;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.mapred.JobConf;


/**
*
* cellid,towerid
* @author Gabriel Kreindler
* @date   23 august 2014
*
*/

public class TowerCsvReader {

	private ArrayList<String> files = new ArrayList<String>(); 
	private static HashMap<String, String> towerMap = new HashMap<String, String>(); //Tower map

	public TowerCsvReader(){
			
		//files.add("/home/gabriel/gabriel_august/input/140802_cell2tower.csv");
		files.add("/home/gabriel/workspace/data/140802_cell2tower.csv");
		
		String hadoopfile = "resources/crosswalk_cell2tower.csv";
	
		try {
			for (int i = 0; i < files.size(); i++) {
				/*
				 * FSDataInputStream FSdataIs = FileSystem.get(new JobConf())
				 * .open(new Path(files.get(i))); InputStreamReader isr = new
				 * InputStreamReader(FSdataIs); CSVReader reader = new
				 * CSVReader(isr);
				 */
	
				CSVReader reader = null;
				try {
					reader = new CSVReader(new FileReader(files.get(i)));
				} catch (Exception e) {
					System.err.println("Nomal loading failed");
					System.err.println(e.getMessage());
					try {
						FSDataInputStream FSdataIs = FileSystem.get(
								new JobConf()).open(new Path(hadoopfile));
						InputStreamReader isr = new InputStreamReader(FSdataIs);
						reader = new CSVReader(isr);
					} catch (IOException e1) {
						e1.printStackTrace();
					}
				}
				/*
				 * CSVReader reader = new CSVReader(new
				 * FileReader(files.get(i))); 
				 */
				String[] nextLine;
				
				while ((nextLine = reader.readNext()) != null) {
					try {
						// Add data to the Cell ID map
						towerMap.put( nextLine[0], nextLine[1] );
						} catch (Exception e) {
						System.out.println(e.toString());
						}
				}
	
			}
		} catch (Exception e) {
			System.out.println(e.toString());
		}

	
}
	
public String getTowerID(String cellID){
	String val=null;
	if(towerMap.containsKey(cellID)){
		val=towerMap.get(cellID);
	}	
return(val);
}

 /* // test that leading CSV works
public static void main(String[] args) {

	TowerCsvReader towerids = new TowerCsvReader();

	if(towerids.getTowerID("1414")==null){
		System.out.println("this was null");
	}else
		System.out.println(towerids.getTowerID("1414"));
} // */

}