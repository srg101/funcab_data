# 2019 NDVI/Reflectance Data from SeedClim/FunCaB Grid
# Data collector: Joshua Lynn
# Code: Joshua Lynn and Sonya R. Geange

# Required Packages
require(coda)
require(car)
library(dplyr)
library(tidyverse)
source("R/load_packages.R")

# Download data from OSF
# Run the code from L10-L13 if you need to download the data from the OSF repository

# get_file(node = "4c5v2",
#          file = "NDVI_FunCaB_2019.csv",
#          path = "data",
#          remote_path = "Vegetation data/Reflectance/Data")

# Read in 2019 reflectance data
# Because of Norwegian characters, use UTF-8 encoding
fundat <- read.csv("./data/NDVI_FunCaB_2019.csv", fileEncoding = "UTF-8")

# Check site names
unique(fundat$Site)
# Clean the site names, Norwegian language read-in issue.
fundat$siteID <- recode(fundat$Site,
                      'Gudmesdalen' = "Gudmedalen",
                      'Låvisdalen' = "Lavisdalen",
                      'Rambæra' = "Rambera",
                      'Ulvehaugen' = "Ulvehaugen",
                      'Skjellingahaugen' = "Skjelingahaugen",
                      'Ålrust' = "Alrust",
                      'Arhelleren' = "Arhelleren",
                      'Fauske' = "Fauske",
                      'Høgsete' = "Hogsete",
                      'Øvstedal' = "Ovstedalen",
                      'Vikesland' = "Vikesland",
                      'Veskre' = "Veskre")

# Check Block and Site ID's
fundat$blocksite <- paste(fundat$siteID, fundat$Block)
unique(fundat$blocksite)

# Turn Site names into Site Codes to merge with block ID's later on
fundat$Site_Code<- recode(fundat$siteID,
                            'Gudmedalen' = "Gud",
                            'Lavisdalen' = "Lav",
                            'Rambera' = "Ram",
                            'Ulvehaugen' = "Ulv",
                            'Skjelingahaugen' = "Skj",
                            'Alrust' = "Alr",
                            'Arhelleren' = "Arh",
                            'Fauske' = "Fae",
                            'Hogsete' = "Hog",
                            'Ovstedalen' = "Ovs",
                            'Vikesland' = "Vik",
                            'Veskre' = "Ves")

# Create new blockID with concatenated Site_Code and Block number
fundat$blockID <- paste(fundat$Site_Code, fundat$Block)

# Standardize dates to data dictionary
fundat$datcor <- as.Date(fundat$Date, "%m/%d/%y")

# For each plot we took two reflectance values, perpindicular to each other to account for the different radius for the greenseeker sensor area, and the 25cm plot size. Average these.
fundat$m_ndvi <- (fundat$Value1+ fundat$Value2)/2 # average the two values

# Check distributon of new NDVI values
hist(logit(fundat$m_ndvi))




# data that I measured
fundat2 <- fundat[fundat$datcor>"2019-08-03",]
head(fundat2)



