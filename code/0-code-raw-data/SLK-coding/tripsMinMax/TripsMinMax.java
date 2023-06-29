package tripsMinMax;

//import main.java.*;

import java.io.IOException;
import java.util.*;
import java.util.Calendar.*;

import org.apache.hadoop.fs.Path;
import org.apache.hadoop.conf.*;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapred.*;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper.Context;
import org.apache.hadoop.mapreduce.lib.input.MultipleInputs;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.*;
import utilities.reader.*;

import utilities.PublicHolidaycsvReader;
import utilities.TowerCsvReader;


/**
 * This Hadoop class will take raw Voice, SMS and GPRS data from company A as input and output individual day (min-max) trips
 * 
 * Example input line: 1|NOKIA1000, 1282|651004263|865545701|40619|20130101102734|20|LOCAL
 * Description: Direction | Phone name | Party A | Party B | Call ID | DateTimeString | Duration | Local/International
 * 
 * Example output line: 1000000984,130701	2823,2823
 * Description: ID, YYMMDD <-Tab-> Tower ID origin, Tower ID destination
 * 
 * @author Gabriel Kreindler, adapted from Danaja's code
 * @date   23 august 2014
 */

public class TripsMinMax {


	public static void main( String[] args ) throws IOException, ClassNotFoundException, InterruptedException{
		
		Configuration conf = new Configuration();
        conf.set("mapred.child.java.opts", "-Xmx2460m -Xss600m");
        conf.set("mapred.job.shuffle.input.buffer.percent","0.4");
        Job job = new Job(conf, "Min-Max Trip job");
        job.setNumReduceTasks(3);
       
        job.setJarByClass(TripsMinMax.class); 
        job.setReducerClass(MinMaxTripReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        //job.setInputFormatClass(TextInputFormat.class);
        //job.setOutputFormatClass(CSVOutputFormat.class);

        MultipleInputs.addInputPath(job, new Path(args[0]), CallReader.class, IdTimeCellMapper.class);
        MultipleInputs.addInputPath(job, new Path(args[1]),  SMSReader.class, IdTimeCellMapper.class);
        MultipleInputs.addInputPath(job, new Path(args[2]), GPRSReader.class, IdTimeCellMapper.class);

        FileOutputFormat.setOutputPath(job, new Path(args[3]));
        //ConfigHandler.getInstance().initialize(args[4]);

        boolean result = job.waitForCompletion(true);

        System.exit(result ? 0 : 1);
		
	}
}