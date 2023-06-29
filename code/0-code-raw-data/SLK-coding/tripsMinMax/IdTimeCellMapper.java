package tripsMinMax;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.HashSet;

import utilities.TowerCsvReader;

/**
 * @author Gabriel Kreindler, adapted from Danaja's code
 * @date   23 august 2014
 */
public class IdTimeCellMapper extends org.apache.hadoop.mapreduce.Mapper<Object, Text, Text, Text> {

	private String Tower, YYMMDD,HHMM;
	TowerCsvReader Towerlist = new TowerCsvReader();

    public IdTimeCellMapper() {

    }

    public void map(Object key, Text value, Context context)
            throws IOException, InterruptedException {

        // ID, time, CellID
    	String[] parts = value.toString().split(",");
    	
    	if( Towerlist.getTowerID(parts[2]) != null ){
			Tower = Towerlist.getTowerID(parts[2]);	 	
			// key = ID,YYMMDD
			// value = towerID,HHMM
			YYMMDD = parts[1].substring(2,8);
			HHMM   = parts[1].substring(8,12);
	        context.write(new Text(parts[0]+","+YYMMDD), new Text(Tower + "," + HHMM));
    	}
    }


}