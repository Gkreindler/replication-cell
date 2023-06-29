/* FormatCommutingInfo.java

uidでsortしたCommutingPanel1のoutputを圧縮し, 整形する
  * useridはtemp/userid_table.csvを使って数値に変換
  * dateは月日だけを残す
  * lon, latは消す

input: userid, date, origin_ant10, origin_lon, origin_lat, 
        destination_ant10, destination_lon, destination_lat

output: usernum, month_day, origin_ant10, destination_ant10
*/

import java.io.IOException;
import java.io.FileReader;
import java.io.BufferedReader;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.stream.Stream;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Formatter;
import java.util.HashMap;


public class FormatCommutingInfo {

  public static HashMap<String, Integer> uid_num_table = new HashMap<String, Integer>();

  public static void format_commuting_info_line_by_line(String input_path_str, String output_path_str) {
    System.out.println("Start converting panel data");

    Path input_path = Paths.get(input_path_str);
    Path output_path = Paths.get(output_path_str);
    
    // create empty output file
    try{
      Files.deleteIfExists(output_path);
      Files.createFile(output_path);
    }
    catch (IOException e) {
      e.printStackTrace();
    }

    // replace uid with unum
    try (Stream<String> stream = Files.lines(input_path)) {
      stream.forEach(line -> {
        String[] vars = line.split(",");
        String uid = vars[0];
        String month_day = vars[1];
        String origin_ant10 = vars[2];
        String destination_ant10 = vars[5];
        Integer unum = uid_num_table.get(uid);
        if (null == unum) {
          String msg = String.format("This uid does not exist in uid table: %s", uid);
          throw new RuntimeException(msg);
        }
        String new_line = String.format("%d,%s,%s,%s\n", unum, month_day, origin_ant10, destination_ant10);
        try {
          Files.write(output_path, new_line.getBytes(), StandardOpenOption.APPEND);
        }
        catch (IOException e) {
          e.printStackTrace();
        }
      });
    }
    catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish converting panel data");
  }


  public static void read_userid_table(String uid_table_path_str) {
    System.out.println("Start reading userid table");

    try (Stream<String> lines = Files.lines(Paths.get(uid_table_path_str))) {
      lines.map(line -> line.split(",")).forEach(
        unum_uid -> uid_num_table.put(unum_uid[1], Integer.parseInt(unum_uid[0]))
        );
    } catch (IOException e) {
      e.printStackTrace();
    }

    System.out.println("Successfully finish reading userid table");
  }


  public static void main(String[] args) throws Exception {

    if (args.length != 3) {
      System.err.println("Need 3 arguments: <input file> <output file> <uid_table_path>");
      System.exit(1);
    }

    String input_path = args[0];
    String output_path = args[1];
    String uid_table_path = args[2];

    read_userid_table(uid_table_path);
    format_commuting_info_line_by_line(input_path, output_path);
  }
}

