library(readtext)
library(stringi)

edit_tex_file <- function(texfile, outfile="", add_resize="", booktabs=T, drop_hline=F){
  
  # read file
  mylines = readtext(texfile)
  mylines = mylines[1,'text']
  
  # add "resizebox" commands at the top and bottom
  if (add_resize != ""){
    mylines <- paste0(paste0("\\resizebox", add_resize, "\n"), 
                      mylines, 
                      "\n }\n")
  }
  
  # booktabs:
  if (booktabs){
    mylines = stri_replace_first_fixed(mylines, "\\\\[-1.8ex]\\hline \n\\hline \\\\[-1.8ex]", "\\toprule ")
    mylines = stri_replace_first_fixed(mylines, "\\hline \n\\hline \\\\[-1.8ex]", "\\bottomrule ")
    }
  
  # remove "hline" commands and replace with "addlinespace"
  if (drop_hline){
    mylines <- gsub("\\hline", "\\addlinespace ", mylines)
  }
  
  # output (to same file by default)
  if (outfile != ""){
    texfile = outfile
  }
  fileConn <- file(texfile)
  writeLines(mylines, fileConn)
  close(fileConn)
  
  "Edited .tex file."
}

unique_id <- function(x, ...) {
  
  # dplyr function to check if column is unique ID
  
  id_set <- x %>% select(...)
  id_set_dist <- id_set %>% distinct
  if (nrow(id_set) == nrow(id_set_dist)) {
    TRUE
  } else {
    non_unique_ids <- id_set %>% 
      filter(id_set %>% duplicated()) %>% 
      distinct()
    suppressMessages(
      inner_join(non_unique_ids, x) %>% arrange(...)
    )
  }
}