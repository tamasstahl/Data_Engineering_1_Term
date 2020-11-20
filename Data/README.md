# Description of the data

## Overview
The 120 Years of Olympic History: Athletes and Results has been uploaded to Kaggle.com and falls under the Creative Commons License. The dataset consisted of two tables; athlete_events.csv and noc_regions.csv. For the purpose of showing my knowledge of joins and understanding relational datasets, athlete_events.csv was divided by me to two separate CSV, olympians.csv and events_final.csv. The olympians.csv dataset contains information about Olympic Athletes including biological data (Age, Sex, Height, Weight) and data about year participated and nation. The events_final.csv dataset contains data about the specific Olympic Events (Year, Season, City, Sport etc.). The Country.csv dataset includes the country code (issued by the National Organizing Committee) and name of the participating countries as well as some notes.

## Contents of the datasets
The Olympians dataset contains 9 variables:

ID: A number used as a unique identifier for each athlete
Name: The athlete’s name(s) in the form of First Middle Last where available
Sex: The athlete’s gender; one of M or F
Age: The athlete’s age in years
Height: The athlete’s height in centimeters (cm)
Weight: The athlete’s weight in kilograms (kg)
Team: The name of the team that the athlete competed for
NOC: The National Organizing Committee’s 3-letter code
Year: The year of the Olympics that the athlete competed in

The events_final dataset contains 8 variables:

ID: A number used as a unique identifier for each athlete
Games: The year and season of the Olympics the athlete competed in in the format YYYY Season
Year: The year of the Olympics that the athlete competed in
Season: The season of the Olympics that the athlete competed in
City: The city that hosted the Olympics that the athlete competed in
Sport: The sport that the athlete competed in
Event: The event that the athlete competed in
Medal: The medal won by the athlete; one of Gold, Silver, or Bronze. NA if no medal was won.

The Country dataset contains 3 variables:

NOC: The National Organizing Committee’s 3-letter code
region: The name of the country/region associated with the NOC code
notes: Any extra/miscellaneous information about the NOC region


An image of the relational dataset used can be found in this folder.
© 2020 GitHub, Inc.
