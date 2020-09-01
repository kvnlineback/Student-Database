
*This application runs a database involving a basic university schema in which students and administrators and make changes to the database*

Instructions to run:

Program is written in Java 8, meant to be run in the terminal or an IDE. Application was written in and tested in Eclipse.

Please see the Entity-Relationship diagram to visualize the database schema and table relationships.

To compile: javac -cp "mysql-connector-java-5.1.21-bin.jar" UniversityDatabase.java
To run: java -cp "mysql-connector-java-5.1.21-bin.jar" UniversityDatabase

To use:

-Database connects automatically, follow prompts to navigate back and forth through the sub-menus to display and enter information. The application will ask for information when it needs it
, enter the required info and press enter to move through the prompts. Program will not die until you quit from the main menu.

-The application will let the user know if the information was input incorrectly, and give another chance to input the correct information

-Use provided sql script to create and populate the database if necessary, there should be data already in the database however.

-Constraints are in place to automatically update the database with the proper information when user adds/edits/deletes anything from the database.

-To exit application, press quit at the main menu
