library(ggplot2)
library(xtable)
library(plyr)
library(scales)
library(grid)

#######################################

# default folder
setwd("Y:/htdocs/benchmark/data")

output <- "pdf"  #can be "png"


vplayout <- function(x, y) viewport(layout.pos.row = x, layout.pos.col = y)

#Drives tested.
listDrives <- c("SAS 3T", "HDD", "SSD")
#Number assigned to it (in filename)
listDrivesInt <- c(0, 1, 2)
pairsDrives <- data.frame(listDrives, listDrivesInt)

# Legend for tests
listTests <- c("btrfs", "btrfs compress=lzo", "btrfs compress=zlib", "ext4", "xfs")
#codename
listTestsInt <- c("btrfs-default", "btrfs-lzo", "btrfs-zlib", "ext4", "xfs-default")
pairsTests <- data.frame(listTests, listTestsInt)

#####################################
comma2 <- function(x, ...) { 
  format(x, decimal.mark = " ", trim = TRUE, scientific = FALSE, ...) 
} 
q95 <- function(x) { quantile(x, probs = c(0.95), na.rm = TRUE) }
q50 <- function(x) { quantile(x, probs = c(0.50), na.rm = TRUE) }

dvf<-data.frame()
dvf<-data.frame()
for (drive in listDrivesInt) {
  for (test in listTestsInt) {
    csvName <- paste("sysbench_", drive, "-", test, ".csv", sep='')
    print(csvName)
    if (file.exists(csvName)){
      td1 <- read.csv(csvName, sep=" ",header=T,comment.char=";")
      dv.ver=as.data.frame(td1)
      dv.ver$engine=pairsTests[which(pairsTests$listTestsInt  == test),]$listTests
      
      dv.ver$storage=pairsDrives[which(pairsDrives$listDrivesInt  == drive),]$listDrives
      dvf=rbind(dvf,dv.ver)
    }
  }
}

# Operations. Missing "rndrd" (something failed when doing benchmark)
hdlatencyOpType <- c("seqrd", "seqwr", "rndwr")

for (drive in listDrives) {
  
  if(output == "pdf") {
    fileName <- paste(drive, ".pdf", sep="")
    pdf(fileName,paper="a4r",width=11, height=8)
  }
  for (opType in hdlatencyOpType) {
    
    if(output == "png") {
      fileName <- paste(drive, "-", opType, ".png", sep="")
      png(fileName, width=11, height=8, res=300, units="in")
    }
    graphName <- paste("Sysbench ", 
                      opType, " ", "- Speed on drive ", drive, sep="")
    
    currentdata <- subset(dvf, storage == drive & testmode == opType)
    
    # No graph when no values
    if (nrow(currentdata) == 0) {
      next
    }
    
    currentdataSummarize <- ddply(currentdata, 
                          c("testmode", "storage",  "engine", "thread", "blocksize"),
                          summarize,
                          rw95 = round(
                            as.numeric(q95(read))+as.numeric(q95(write)), digits=8
                          ),
                          rw50 = round(
                                    as.numeric(q50(read))+as.numeric(q50(write)), digits=8
                                    )
                          )

    m <-ggplot(currentdata,
               aes(x =factor(thread), y = read+write,
                   fill=factor(engine), colour=factor(engine)
                   )
               )
    print(m + geom_jitter(size=1, alpha=0.75) +
      scale_fill_hue(name ="Filesystems: ")+
      facet_grid(blocksize ~ engine , scales = "free_y")+
      xlab("Threads")+
      opts(title = graphName)+
      opts(legend.position = "none")+
      scale_y_continuous(labels=comma, name="Speed (MB/s)")
          )
    
    if(output == "png") {
      dev.off()
      fileName <- paste(drive, "-", opType, "-values.png", sep="")
      png(fileName, width=11, height=8, res=300, units="in")
    }
    
    graphName <- paste("Sysbench ", 
                       opType, "(95P) ", "- Speed on drive ", drive, sep="")

    # IO SIZE list should be written here (can be made automatic ...)
    tabIOSIZE <- c(512, 4096, 16384, 1048576)
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(2, 3)))
    
    i <- 1
    j <- 1
    
    for (tabS in tabIOSIZE) {
      
      m <- ggplot(subset(currentdataSummarize, blocksize == tabS),
                 aes(x =factor(thread), y = rw95,
                     fill=factor(engine), colour=factor(engine), group=factor(engine)
                     )
                 )
      m <- m + 
        geom_point()+
        geom_line(alpha=0.8) +
       
        opts(legend.position = "none")+
        xlab(paste(opType, tabS))+
        scale_y_continuous(labels=comma, name="")
             
      print(m, vp = vplayout(i, j))
      
      if (j == 3) {
        j <- 1
        i <- i+1
      } else {
        j <- j+1
      }
      
      
     
    }

    
    if(output == "png") {
      dev.off() 
    }
    
  }
  if(output == "pdf") {
    dev.off()
  } 


}
# working !
