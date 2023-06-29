package tripsMinMax;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

import java.io.IOException;
import java.util.*;


/**
 *
 * @author Gabriel Kreindler, adapted from Danaja's code
 * @date   23 august 2014
 *
 */
public class MinMaxTripReducer extends org.apache.hadoop.mapreduce.Reducer<Text, Text, Text, Text> {

    //private BaseStationHandlerB bth;
	private static int S_LOWER_BOUND_HOUR = 500;
    private static int S_UPPER_BOUND_HOUR = 1000;
    private static int D_LOWER_BOUND_HOUR = 1000;
    private static int D_UPPER_BOUND_HOUR = 1500;
    
    private Integer HHMM, min_time, max_time;
    private String min_tower, max_tower,line;
    
    public MinMaxTripReducer()
    {
      //  bth = BaseStationHandlerB.getBaseStationHandler();
    }

    protected void reduce(Text key, Iterable<Text> values, Context context)
            throws IOException, InterruptedException {

    	Iterator<Text> vals = values.iterator();
    	
    	min_time=9999;
    	max_time=-1;
    	
    	min_tower="X";
    	max_tower="X";
    	
    	while (vals.hasNext()) {
	 		line = vals.next().toString();
	 		String[] parts = line.split(","); // towerID,HHMM
	 		
	 		HHMM = Integer.valueOf(parts[1]);
	 			 		
	 		if( HHMM >= S_LOWER_BOUND_HOUR && HHMM <= S_UPPER_BOUND_HOUR)
	 			if(HHMM < min_time){
	 				min_time = HHMM;
	 				min_tower = parts[0];
	 			}
	 		

 			if(HHMM > D_LOWER_BOUND_HOUR && HHMM <= D_UPPER_BOUND_HOUR)
 				if(HHMM > max_time){
	 				max_time = HHMM;
	 				max_tower = parts[0];
	 			}
    	}				
 	 		
    	// acceptable as trip only if determined by 2 (distinct) events
    	if(min_time < 9999 && max_time > -1 && min_time != max_time){
	    	/*List<String> outStrings = null;
	    	outStrings = new ArrayList<String>();
	    	outStrings.add("blaa");*/
	    	
	        context.write(key, new Text(min_tower + "," + max_tower));
    	}
	 		
    	
    }
}
