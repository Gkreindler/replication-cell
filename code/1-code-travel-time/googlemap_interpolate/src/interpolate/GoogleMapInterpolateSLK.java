/*
 * Author: Yuhei Miyauchi
 * Last Edited: July 4th, 2017
 * 
 * Description: 
 * 	Create interpolated tower pair data of google map travel time in traffic, travel time and travel distance	
 */


package interpolate;

import java.io.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

public class GoogleMapInterpolateSLK {

	public static void main(String[] args) throws IOException  {
		// Input files
			String path = "D:/Dropbox (Personal)/projects/BGD_SLK_cellphone/for_publication/data_coded_slk/travel-times"; 
			String file1 = path + "all tower pair within 50km before interpolation.csv";
			String file2 = path + "random 90000 towe pair within 50km - google prediction before interpolation.csv";
			
		// Output files
			String outfile = path + "all tower pair within 50 km after interpolation.csv";
			String outfile_aux = path + "all tower pair within 50 km after interpolation auxiliary.csv";
			
		// Parameters
			int n_towers = 3060;
			//int n_towers = 3047;
			double bw = 0.1;
		
		// DECLARATIONS		
			int n, itower;
			Integer o_temp, d_temp;
			double sum, w;
			
		// index (b/w 0 and 3046) corresponding to tower code	
			HashMap<Integer,Integer> tower2n = new HashMap<Integer,Integer>(); 
		
		// tower code corresponding to index			
			Integer[] n2tower = new Integer[n_towers];
			
		// tower coordinates and "radius"	
			double[] lat = new double[n_towers];
			double[] lon = new double[n_towers];
			double[]   h = new double[n_towers];
				
		// matrix of duration_in_traffic (original and interpolated)	
			double[][] duration_orig    = new double[n_towers][n_towers];
			double[][] duration_intp = new double[n_towers][n_towers];
			double[][] duration_in_traffic_orig    = new double[n_towers][n_towers];
			double[][] duration_in_traffic_intp = new double[n_towers][n_towers];
			double[][] distance_orig    = new double[n_towers][n_towers];
			double[][] distance_intp = new double[n_towers][n_towers];

			byte[][]   isflow = new   byte[n_towers][n_towers]; // 0 = missing, 1 = data exist
			double[][] sldist    = new double[n_towers][n_towers]; // straightline distance

		// INPUT DATA
			
			itower=0;
			n=0;

			
			// Input 1: straightline distance data (for all pairs)
			System.out.println("Reading straightline distance data");
		
			BufferedReader br = new BufferedReader(new FileReader(file1));
			String line, newline;
			
			while ((line = br.readLine()) != null) {
				
				// display progress
					if((n++)%100000==0) System.out.print(".");
				
				// process the line : dest_long dest_lat dest_tower orig_long orig_lat orig_tower dist h_d h_o
					String[] parts= line.split("\\,");
					

				//add assign index to orig and dest if haven't done so already
					o_temp = Integer.valueOf(parts[5]);
					d_temp = Integer.valueOf(parts[2]);

					if(!tower2n.containsKey(d_temp)){
						// save tower coordinates and radius
						lon[itower]=Double.valueOf(parts[0]);
						lat[itower]=Double.valueOf(parts[1]);
						h[itower]=Double.valueOf(parts[7]);
						n2tower[itower] = d_temp;
						tower2n.put(d_temp, itower++);
					}					
					if(!tower2n.containsKey(o_temp)){
						// save tower coordinates and radius
						System.out.println(itower);
						lon[itower]=Double.valueOf(parts[3]);
						lat[itower]=Double.valueOf(parts[4]);
						h[itower]=Double.valueOf(parts[8]);
						n2tower[itower] = o_temp;
						tower2n.put(o_temp, itower++);
					}
					
				// save straightline distance
					sldist[tower2n.get(o_temp)][tower2n.get(d_temp)] = Double.valueOf(parts[6]);
			}
			
			br.close();

			
			System.out.println("#towers = " + String.valueOf(itower));

			
			// Input 2: google travel time data
			System.out.println("Reading googlemap travel time");	

			br = new BufferedReader(new FileReader(file2));
			
			while ((line = br.readLine()) != null) {
				
				// display progress
					if((n++)%100000==0) System.out.print(".");
				
				// process the line : dest_long dest_lat dest_tower orig_long orig_lat orig_tower dist odid duration_bg duration_in_traffic_bg distance_bg h_d h_o

					String[] parts= line.split("\\,");
					
				//add assign index to orig and dest if haven't done so already
					o_temp = Integer.valueOf(parts[5]);
					d_temp = Integer.valueOf(parts[2]);

					if(!tower2n.containsKey(d_temp)){
						// save tower coordinates and radius
						lon[itower]=Double.valueOf(parts[0]);
						lat[itower]=Double.valueOf(parts[1]);
						h[itower]=Double.valueOf(parts[11]);
						n2tower[itower] = d_temp;
						tower2n.put(d_temp, itower++);
					}					
					if(!tower2n.containsKey(o_temp)){
						// save tower coordinates and radius
						lon[itower]=Double.valueOf(parts[3]);
						lat[itower]=Double.valueOf(parts[4]);
						h[itower]=Double.valueOf(parts[12]);
						n2tower[itower] = o_temp;
						tower2n.put(o_temp, itower++);
					}

				// save duration_in_traffic_orig
					duration_orig[tower2n.get(o_temp)][tower2n.get(d_temp)] = Double.valueOf(parts[8]);
					duration_in_traffic_orig[tower2n.get(o_temp)][tower2n.get(d_temp)] = Double.valueOf(parts[9]);
					distance_orig[tower2n.get(o_temp)][tower2n.get(d_temp)] = Double.valueOf(parts[10]);
					isflow[tower2n.get(o_temp)][tower2n.get(d_temp)] = 1;
					
			}
			
			br.close();

			
			System.out.println("#towers = " + String.valueOf(itower));
			
			
			
		// Populate kernel matrix
			System.out.println("Populating Kernel matrix");
			
			// kernel and (K>0) matrix	
				double[][] K = new double[n_towers][n_towers];
				byte[][] nbs = new   byte[n_towers][n_towers];
				double dlat, dlon, temp;
			
			// K[i1][i2] = weight we should put on i2 when smoothing at i1
			for(int i1=0;i1<n_towers;i1++){
				for(int i2=0;i2<n_towers;i2++){
					
					// Put 0 weight if i1 and i2 are different and not too distant.
					if(i1!=i2){
						// divide by i2's radius (h)
						dlat = (lat[i1]-lat[i2])/h[i2]/bw;
						dlon = (lon[i1]-lon[i2])/h[i2]/bw;
						temp = Math.max(0.0, 1.0 - dlat*dlat - dlon*dlon);
						
						K[i1][i2] = 3 / Math.PI * (temp*temp) / h[i2] / bw;
						
						if(temp>0.0) nbs[i1][i2]=1;
					}
				}
			}
			
			// calculate average number of "neighbors"
				int nsum = 0;
				int[] nnbs = new int[n_towers]; // vector of number of neighbors
				for(int i=0;i<n_towers;i++){
					for(int j=0;j<n_towers;j++){
						nnbs[i] += nbs[i][j];
					}
					nsum += nnbs[i];
				}
				System.out.print("Average number of neighbors (=positive weight) = " + String.valueOf(nsum/n_towers) + "\n");
				
			// organize meighbors in list 
				/*int[] nbs_list  = new int[nsum];
				int[] nbs_start = new int[3048];
				
				int index = 0;
				
				for(int i=0;i<n_towers;i++){
					nbs_start[i]=index;
					for(int j=0;j<n_towers;j++)
					if(nbs[i][j]==1){
						nbs_list[index++] = j;
					}
				}
				nbs_start[n_towers]=index;
				assert(index==nsum);
				
				System.out.print("Done creating nbs list \n");*/
				
				
		// Let's interpolate!
			System.out.println("Interpolating");
			
			//System.arraycopy( duration_in_traffic_orig, 0, duration_in_traffic_intp, 0, duration_in_traffic_orig.length );
			
			for(int i1=0;i1<n_towers;i1++){
				long startTime = System.nanoTime();
				
				for(int j1=0;j1<n_towers;j1++){

					/* for smoothing duration_in_traffic */
					sum = 0.0; // (weighted) sum of neighboring duration_in_traffic 
					w = 0.0;   // sum of weights
					n=0;     // number of neighboring duration_in_traffic
					
					/* for smoothing duration and distance */
					double sum_v2 = 0.0; // duration
					double sum_v3 = 0.0; // distance

					// loop over neighbors
					for(int i2=0;i2<n_towers;i2++){
						if(nbs[i1][i2]==1){ // only if i1 is not too distant from i2
							for(int j2=0;j2<n_towers;j2++){
								if(nbs[j1][j2]==1){ // only if j1 is not too distant from j2
									if(isflow[i2][j2] == 1){ // only if we have travel time from i2 to j2
										sum += K[i1][i2]*K[j1][j2]*duration_in_traffic_orig[i2][j2]/sldist[i2][j2];
										sum_v2 += K[i1][i2]*K[j1][j2]*duration_orig[i2][j2]/sldist[i2][j2];
										sum_v3 += K[i1][i2]*K[j1][j2]*distance_orig[i2][j2]/sldist[i2][j2];
										  w += K[i1][i2]*K[j1][j2];
										  n++;
										  

									}
								}
							}
						}
					}	
					
				duration_in_traffic_intp[i1][j1] = sum/w*sldist[i1][j1];
				duration_intp[i1][j1] = sum_v2/w*sldist[i1][j1];
				distance_intp[i1][j1] = sum_v3/w*sldist[i1][j1];
				}
				
				long endTime = System.nanoTime();
				long duration = (endTime - startTime)/1000000L;  //divide by 1000000 to get milliseconds.
				System.out.println("tower " + String.valueOf(i1) + " took (ms): " + String.valueOf(duration));
		}
				
		// OUTPUT 
		System.out.println("Main output");
		System.out.println("Output folder: " + path);
		File fileout = new File(outfile);
	    
		// if file doesn't exist, then create it
		if (!fileout.exists()) {
			fileout.createNewFile();
		}

		FileWriter fw = new FileWriter(fileout.getAbsoluteFile());
		BufferedWriter bfw = new BufferedWriter(fw);
		
		bfw.write("orig,dest,sldist,duration_in_traffic_orig,duration_in_traffic_intp,duration_orig,duration_intp,distance_orig,distance_intp");
		bfw.newLine();
		
		for(int i=0;i<n_towers;i++)
			for(int j=0;j<n_towers;j++){
				if(sldist[i][j]>0){
					bfw.write(n2tower[i] + "," + n2tower[j] + "," + sldist[i][j] + "," + duration_in_traffic_orig[i][j] + "," + duration_in_traffic_intp[i][j] + 
							 "," + duration_orig[i][j] + "," + duration_intp[i][j]+ "," + distance_orig[i][j]+ "," + distance_intp[i][j]);
					bfw.newLine();
				}
			}

		bfw.close();
		
	// auxiliary output 
		System.out.println("Aux output");
		fileout = new File(outfile_aux);
		    
			// if file doesn't exist, then create it
			if (!fileout.exists()) {
				fileout.createNewFile();
			}

			fw = new FileWriter(fileout.getAbsoluteFile());
			bfw = new BufferedWriter(fw);
			
			bfw.write("tower,nnbs,lat,lon");
			bfw.newLine();
			
			for(int i=0;i<n_towers;i++){
				bfw.write(n2tower[i] + "," + nnbs[i] + "," + lat[i] + "," + lon[i]);
				bfw.newLine();
			}

		bfw.close();
	}	
}



