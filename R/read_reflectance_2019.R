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
fundat <- read.delim("./data/NDVI_FunCaB_2019.csv", fileEncoding = "UTF-8",
                     sep = ",")

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
unique(fundat$siteID)

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
fundat$blockID <- paste0(fundat$Site_Code, fundat$Block)
unique(fundat$blockID)

# Standardize dates to data dictionary
fundat$date <- as.Date(fundat$Date, "%m/%d/%y")

# For each plot we took two reflectance values, perpindicular to each other to account for the different radius for the greenseeker sensor area, and the 25cm plot size. Average these.
fundat$m_ndvi <- (fundat$Value1+ fundat$Value2)/2 # average the two values

# Check distributon of new NDVI values
hist(logit(fundat$m_ndvi))

# Add column to specify when reflectance was taken relative to cutting
fundat$pre_post_cut <- "post_cut"

# Remove columns no longer required
NDVI_2019 <- fundat %>%
  select(siteID, blockID, Treatment, TTC_ID, pre_post_cut,
         date, Time, m_ndvi, notes)

# Write file
write_csv(NDVI_2019, "./data/NDVI_2019.csv")


