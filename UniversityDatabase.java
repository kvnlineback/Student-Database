import java.sql.*;
import java.util.*;
import javax.sql.StatementEvent;
import java.io.*;

public class UniversityDatabase {
	private static Connection conn = null;
	private static BufferedReader input = null;
	private static Statement statement = null;
	private static String query = null;
	private static ResultSet rs = null;

	public static void main(String[] args) {
		setupConnection();
		boolean mainFlag = true;
		System.out.println(
				"Welcome to the university database, please select an option from the main menu by pressing the corresponding number");
		while (mainFlag) {
			System.out.println();
			System.out.println("\t MAIN MENU");
			System.out.println("(1) Student functions");
			System.out.println("(2) Administrative functions");
			System.out.println("(3) Reporting functions");
			System.out.println("(4) Quit Program");
			try {
				String response = input.readLine();
				switch (response) {
				case "1":
					studMenu();
					break;
				case "2":
					adminMenu();
					break;
				case "3":
					reportMenu();
					break;
				case "4":
					mainFlag = false;
					System.out.println("Disconnected from the database");
					conn.close();
					input.close();
					break;
				default:
					System.out.println("Not a valid choice");
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}

	private static void setupConnection() {
		try {
			input = new BufferedReader(new InputStreamReader(System.in));
			Class.forName("oracle.jdbc.OracleDriver");
			conn = DriverManager.getConnection("jdbc:oracle:thin:@acadoradbprd01.dpu.depaul.edu:1521:ACADPRD0",
					"klinebac", "cdm1939979");
			statement = conn.createStatement();
			// CallableStatement cs = conn.prepareCall("{call fill_data()}"); //calls a
			// procedure to populate database
			// cs.execute();
		} catch (ClassNotFoundException e) {
			e.printStackTrace();
		} catch (SQLException e) {
			System.out.println("Could not connect to database");
		}

	}

	private static void studMenu() {
		boolean studFlag = true;
		while (studFlag) {
			System.out.println("\t STUDENT FUNCTIONS MENU");
			System.out.println("(1) Add/drop a course");
			System.out.println("(2) Request Transcript");
			System.out.println("(3) Pay Fees (get a fee report)");
			System.out.println("(4) Quit");
			try {
				String response = input.readLine();
				switch (response) {
				case "1":
					addDropCourse();
					break;
				case "2":
					requestTranscript();
					break;
				case "3":
					payFees();
					break;
				case "4":
					studFlag = false;
					break;
				default:
					System.out.println("not a valid choice");
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}

	private static void addDropCourse() {
		String stdId = null;
		String term = null;
		boolean dropFlag = true;
		while (dropFlag) {
			System.out.println("(1) Add a course to Schedule");
			System.out.println("(2) Drop a course from Schedule");
			System.out.println("(3) Quit");
			try {
				String response = input.readLine();
				if (response.equals("1")) {
					System.out.println("Please enter your student ID");
					stdId = input.readLine();
					System.out.println("Please enter the section number of the class you'd like to add");
					String newClass = input.readLine();
					query = ("SELECT term FROM sections where sectno = " + newClass);
					rs = statement.executeQuery(query);
					while (rs.next()) {
						term = rs.getString("term");
					}
					Random rand = new Random();
					double gpa = Math.round((2.5f + rand.nextFloat() * (4.0f - 2.5f)) * 100.0) / 100.0;
					query = "INSERT INTO enrollment(SID,term,sectno,grade) VALUES(" + stdId + "," + "'" + term + "'"
							+ "," + newClass + "," + String.valueOf(gpa) + ")";
					statement.executeUpdate(query);
					query = "SELECT ctitle from courses inner join sections on courses.cno = sections.cno WHERE sectno = "
							+ newClass;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						System.out.println("Successfully added " + rs.getString("ctitle")
								+ " to your course list, your student account balance has increased by $500");
					}
				} else if (response.equals("2")) {
					System.out.println("Please enter your student ID");
					stdId = input.readLine();
					System.out.println("Please enter the section number of the class you'd like to drop");
					String dropClass = input.readLine();
					query = "DELETE FROM enrollment WHERE SID = " + stdId + " AND sectno = " + dropClass;
					statement.executeUpdate(query);
					double gpa = 0.0;
					query = "SELECT ROUND(AVG(grade),2) from enrollment where SID = " + stdId;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						gpa = rs.getDouble(1);
					}
					query = "UPDATE students SET gpa = " + gpa + " WHERE SID = " + stdId;
					statement.executeUpdate(query);
					int hours = 0;
					query = "SELECT hours from students where SID = " + stdId;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						hours = rs.getInt("hours");
					}
					int newHours = 0;
					query = "SELECT c.hours from courses c join sections s on c.cno = s.cno where s.sectno ="
							+ dropClass;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						newHours = rs.getInt("hours");
					}
					query = "UPDATE students SET hours = " + (hours - newHours) + " WHERE SID = " + stdId;
					statement.executeUpdate(query);
					query = "SELECT ctitle from courses inner join sections on courses.cno = sections.cno WHERE sectno = "
							+ dropClass;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						System.out.println("Successfully dropped " + rs.getString("ctitle") + " from your course list");
					}

				} else if (response.equals("3")) {
					dropFlag = false;
				} else {
					System.out.println("not a valid response");
				}
			} catch (IOException e) {
				e.printStackTrace();
			} catch (SQLException e) {
				System.out.println("Received eror, make sure your student id and section number were input correctly");
			}
		}
	}

	private static void requestTranscript() {
		System.out.println("Please enter student ID");
		try {
			String stdId = input.readLine();
			String firstName = null;
			String lastName = null;
			query = "SELECT last_name, first_name from students where SID = " + stdId;
			rs = statement.executeQuery(query);
			while (rs.next()) {
				firstName = rs.getString("first_name");
				lastName = rs.getString("last_name");
			}
			query = "SELECT * from enrollment where SID = " + stdId;
			rs = statement.executeQuery(query);
			System.out.println("\tTranscript for " + firstName + " " + lastName);
			while (rs.next()) {
				System.out.println("Term: " + rs.getString("term") + " " + "section number: " + rs.getInt("sectno")
						+ " " + "grade: " + rs.getDouble("Grade"));
			}

		} catch (SQLException e) {
			System.out.println("Cannot find a transcript with that id");
		} catch (Exception e) {
			e.printStackTrace();
		}

	}

	private static void payFees() {
		String stdId = null;
		int balance = 0;
		System.out.println("Please enter your student ID");
		try {
			stdId = input.readLine();
			query = "SELECT balance from studentaccounts where SID = " + stdId;
			rs = statement.executeQuery(query);
			while (rs.next()) {
				balance = rs.getInt("balance");
			}
			System.out.println("Your current balance is " + "$" + balance);
			boolean payFlag = true;
			while (payFlag) {
				System.out.println("(1) Pay Balance");
				System.out.println("(2) Quit");
				String option = input.readLine();
				if (option.equals("1")) {
					int pay = 0;
					System.out.println("Please enter amount to pay");
					pay = Integer.parseInt(input.readLine());
					query = "UPDATE studentaccounts SET balance = " + (balance - pay) + " WHERE SID = " + stdId;
					statement.executeUpdate(query);
					query = "SELECT balance from studentaccounts where SID = " + stdId;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						balance = rs.getInt("balance");
						System.out.println("Your balance is now " + "$" + balance);
					}
				} else if (option.equals("2")) {
					payFlag = false;
				} else {
					System.out.println("Not a valid selection");
				}
			}
		} catch (SQLException e) {
			System.out.println("Failed to locate your student account");
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	private static void adminMenu() {
		boolean adminFlag = true;
		while (adminFlag) {
			System.out.println("\t ADMINISTRATIVE FUNCTIONS MENU");
			System.out.println("(1) Create/remove course");
			System.out.println("(2) Add/drop sections");
			System.out.println("(3) Add/drop instructors");
			System.out.println("(4) Add/drop students");
			System.out.println("(5) Quit");
			try {
				String response = input.readLine();
				switch (response) {
				case "1":
					createRemoveCourse();
					break;
				case "2":
					addDropSections();
					break;
				case "3":
					addDropInstructors();
					break;
				case "4":
					addDropStudents();
					break;
				case "5":
					adminFlag = false;
					break;
				default:
					System.out.println("not a valid choice");
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}

	private static void createRemoveCourse() {
		int cno = 0;
		String ctitle = null;
		int hours = 0;
		int dept_id = 0;
		boolean removeFlag = true;
		while (removeFlag) {
			System.out.println("(1) Add Course");
			System.out.println("(2) Remove Course");
			System.out.println("(3) Quit");
			try {
				String option = input.readLine();
				if (option.contentEquals("1")) {
					System.out.println("Please enter a course name");
					ctitle = input.readLine();
					System.out.println("Please enter a deptartment id");
					dept_id = Integer.valueOf(input.readLine());
					System.out.println("Please enter number of credit hours");
					hours = Integer.valueOf(input.readLine());
					query = "SELECT max(cno) from courses";
					rs = statement.executeQuery(query);
					while (rs.next()) {
						cno = rs.getInt(1) + 1;
					}
					query = "INSERT INTO courses VALUES(" + cno + "," + "'" + ctitle + "'" + "," + hours + "," + dept_id
							+ ")";
					statement.executeUpdate(query);
					System.out.println("Successfully added " + ctitle + "/course # " + cno + " to the course catalog");
				} else if (option.contentEquals("2")) {
					System.out.println("Please enter the course number of the course to be removed");
					String removeCourse = input.readLine();
					String name = null;
					query = "SELECT ctitle from courses where cno = " + removeCourse;
					rs = statement.executeQuery(query);
					while (rs.next()) {
						name = rs.getString("ctitle");
					}
					query = "DELETE from courses where cno = " + removeCourse;
					statement.executeUpdate(query);
					System.out.println("Successfully removed " + name + " from the course catalog");
				} else if (option.contentEquals("3")) {
					removeFlag = false;
				} else {
					System.out.println("Not a valid option");
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

	}

	private static void addDropSections() {
		boolean dropFlag = true;
		while (dropFlag) {
			try {
				System.out.println("(1) Add a section");
				System.out.println("(2) Drop a section");
				System.out.println("(3) Quit");
				String choice = input.readLine();
				if (choice.equals("1")) {
					String term = null;
					String cno = null;
					String lname = null;
					String fname = null;
					String room = null;
					String days = null;
					String startTime = null;
					String endTime = null;
					int sectNo = 0;
					System.out.println("Please enter term");
					term = capitalize(input.readLine());
					System.out.println("Please enter the course #");
					cno = input.readLine();
					System.out.println("Please enter professor's last name");
					lname = capitalize(input.readLine());
					System.out.println("Please enter professor's first name");
					fname = capitalize(input.readLine());
					System.out.println("Please enter room # (must be a 3 digit number)");
					room = input.readLine();
					System.out.println("Please enter session days");
					days = input.readLine();
					System.out.println("Please enter a start time (must be a 4 digit number)");
					startTime = input.readLine();
					System.out.println("Please enter an end time (must be a 4 digit number)");
					endTime = input.readLine();
					query = "SELECT max(sectno) from sections";
					rs = statement.executeQuery(query);
					while (rs.next()) {
						sectNo = rs.getInt(1) + 1;
					}
					query = "INSERT INTO sections VALUES(" + "'" + term + "'" + "," + sectNo + "," + cno + "," + "'"
							+ lname + "'" + "," + "'" + fname + "'" + "," + room + "," + "'" + days + "'" + ","
							+ startTime + "," + endTime + "," + "20" + ")";
					statement.executeUpdate(query);
					System.out.println("Successfully added section, section number for this course: " + sectNo);
				} else if (choice.equals("2")) {
					System.out.println("Please enter the term of the course to be removed");
					String term = input.readLine();
					System.out.println("Please enter the section number of the section to be removed");
					String course = input.readLine();
					query = "DELETE from enrollment where enrollment.sectno = " + course + " AND enrollment.term = "
							+ "'" + term + "'";
					statement.executeUpdate(query);
					query = "DELETE from sections where term = " + "'" + term + "'" + " AND sectno = " + course;
					statement.executeUpdate(query);
					System.out.println("Successfully removed section " + course + "/" + term);
				} else if (choice.equals("3")) {
					dropFlag = false;
				} else {
					System.out.println("Not a valid choice");
				}

			} catch (SQLException e) {
				System.out.println("Unable to add/remove course, please make sure info was entered correctly");
				e.printStackTrace();
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

	}

	private static void addDropInstructors() {
		boolean addFlag = true;
		while (addFlag) {
			try {
				System.out.println("(1) Add an instructor");
				System.out.println("(2) Drop an instructor");
				System.out.println("(3) Quit");
				String choice = input.readLine();
				if (choice.equals("1")) {
					System.out.println("Please enter last name");
					String lname = capitalize(input.readLine());
					System.out.println("Please enter first name");
					String fname = capitalize(input.readLine());
					System.out.println("Please enter department id");
					String dept_id = input.readLine();
					System.out.println("Please enter office location");
					String office = input.readLine();
					System.out.println("Please enter phone number in xxx-xxx-xxxx format");
					String phone = input.readLine();
					System.out.println("Please enter email address");
					String email = input.readLine();
					query = " INSERT INTO instructors VALUES(" + "'" + lname + "'" + "," + "'" + fname + "'" + ","
							+ dept_id + "," + "'" + office + "'" + "," + "'" + phone + "'" + "," + "'" + email + "'"
							+ ")";
					statement.executeUpdate(query);
					System.out.println("Successfully added " + fname + " " + lname + " to the database");
				} else if (choice.equals("2")) {
					System.out.println("Please enter first name of instructor");
					String fname = capitalize(input.readLine());
					System.out.println("Please enter last name of instructor");
					String lname = capitalize(input.readLine());
					query = "DELETE from instructors where last_name =" + "'" + lname + "'" + " AND first_name = " + "'"
							+ fname + "'";
					statement.executeUpdate(query);
					System.out.println("Successfully removed " + fname + " " + lname + " from the database");
				} else if (choice.equals("3")) {
					addFlag = false;
				} else {
					System.out.println("Not a valid choice");
				}
			} catch (Exception e) {
				System.out.println("Unable to add/remove instructor, please make sure the information is correct");
				e.printStackTrace();
			}
		}
	}

	private static void addDropStudents() {
		boolean addDropFlag = true;
		while (addDropFlag) {
			try {
				System.out.println("(1) Add a student");
				System.out.println("(2) Drop a student");
				System.out.println("(3) Quit");
				String choice = input.readLine();
				if (choice.contentEquals("1")) {
					String SID = null;
					System.out.println("Please enter first name");
					String fname = capitalize(input.readLine());
					System.out.println("Please enter last name");
					String lname = capitalize(input.readLine());
					System.out.println("Please enter graduating year");
					String year = input.readLine();
					System.out.println("Please enter phone number in xxx-xxx-xxxx format");
					String phone = input.readLine();
					System.out.println("Please enter street address");
					String street = input.readLine();
					System.out.println("Please enter city");
					String city = input.readLine();
					System.out.println("Please enter state as XX");
					String state = input.readLine();
					System.out.println("Please enter zip");
					String zip = input.readLine();
					System.out.println("Please enter degree");
					String degree = input.readLine();
					System.out.println("please enter department id");
					String dept_id = input.readLine();
					query = "select max(SID) from students";
					rs = statement.executeQuery(query);
					while (rs.next()) {
						SID = String.valueOf(rs.getInt(1) + 1);
					}
					query = "INSERT INTO students VALUES(" + SID + "," + "'" + lname + "'" + "," + "'" + fname + "'"
							+ "," + year + "," + "'" + phone + "'" + "," + "'" + street + "'" + "," + "'" + city + "'"
							+ "," + "'" + state + "'" + "," + zip + "," + "'" + degree + "'" + "," + dept_id + "," + "0"
							+ "," + "0.0" + ")";
					statement.executeUpdate(query);
					System.out.println(
							"Successfully added " + fname + " " + lname + "/student id: " + SID + " to the database");
				} else if (choice.contentEquals("2")) {
					System.out.println("Please enter SID of student to remove");
					String sid = input.readLine();
					query = "DELETE from enrollment where SID = " + sid;
					statement.executeUpdate(query); // removes fk dependancy
					query = "DELETE FROM studentaccounts where SID = " + sid;
					statement.executeUpdate(query);
					query = "DELETE from students where SID = " + sid;
					statement.executeUpdate(query);
					System.out.println("Successfully removed student " + sid + " from the database");
				} else if (choice.contentEquals("3")) {
					addDropFlag = false;
				} else {
					System.out.println("Not a valid choice");
				}
			} catch (Exception e) {
				System.out.println("Unable to add/remove student, make sure information was entered correctly");
				e.printStackTrace();
			}
		}
	}

	private static void reportMenu() {
		boolean reportFlag = true;
		while (reportFlag) {
			System.out.println("\t REPORTING FUNCTIONS MENU");
			System.out.println("(1) Print schedule of classes (for a term)");
			System.out.println("(2) Print the catalog");
			System.out.println("(3) Print the honors list(gpa of 3.0+) of students for a department");
			System.out.println("(4) Quit");

			try {
				String response = input.readLine();
				switch (response) {
				case "1":
					printSchedule();
					break;
				case "2":
					printCatalog();
					break;
				case "3":
					printHonorsList();
					break;
				case "4":
					reportFlag = false;
					break;
				default:
					System.out.println("Not a valid choice");
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}
	}

	private static String capitalize(String str) {
		if (str == null || str.isEmpty()) {
			return str;
		}
		return str.substring(0, 1).toUpperCase() + str.substring(1);
	}

	private static void printSchedule() {
		System.out.println("Please enter term");
		try {
			String term = capitalize(input.readLine());
			query = "SELECT * from sections where term = " + "'" + term + "'";
			rs = statement.executeQuery(query);
			System.out.println("\t\t\t\t\t\t\t\t\tSchedule of classes for " + term + " term");
			while (rs.next()) {
				int sectno = rs.getInt("sectno");
				int cno = rs.getInt("cno");
				String lname = rs.getString("instr_lname");
				String fname = rs.getString("instr_fname");
				String room = rs.getString("room");
				String days = rs.getString("days");
				String start = rs.getString("start_time");
				String end = rs.getString("end_time");
				int cap = rs.getInt("capacity");
				System.out.println("Term: " + term + " " + "section number: " + sectno + " " + "course number: " + cno
						+ " " + "instructor lname: " + lname + " " + "instructor fname: " + fname + " " + "room: "
						+ room + " " + "days: " + days + " " + "start time: " + start + " " + "end time: " + end + " "
						+ " class capacity: " + cap);
			}

		} catch (Exception e) {
			System.out.println("Unable to retrieve schedule");

		}
	}

	private static void printCatalog() {
		query = "SELECT * from courses";
		try {
			rs = statement.executeQuery(query);
			System.out.println("\t\tCurrent course catalog");
			while (rs.next()) {
				int cno = rs.getInt("cno");
				String ctitle = rs.getString("ctitle");
				int hours = rs.getInt("hours");
				int dept_id = rs.getInt("dept_id");
				System.out.println("course number: " + cno + " " + "course title: " + ctitle + " " + "hours: " + hours
						+ " " + "department id: " + dept_id);
			}

		} catch (Exception e) {
			System.out.println("Unable to retrieve course catalog");
		}
	}

	public static void printHonorsList() {
		System.out.println("Please enter a department id");
		try {
			String dept = input.readLine();
			String dept_name = null;
			query = "SELECT dept_name from departments where dept_id = " + dept;
			rs = statement.executeQuery(query);
			while (rs.next()) {
				dept_name = rs.getString("dept_name");
			}
			System.out.println("\tHonors list for " + dept_name);
			query = "SELECT first_name, last_name, dept_id, gpa FROM students WHERE  students.dept_id = " + dept
					+ " AND gpa > 3.0";
			rs = statement.executeQuery(query);
			while (rs.next()) {
				String fname;
				fname = rs.getString("first_name");
				String lname = rs.getString("last_name");
				int dept_id = rs.getInt("dept_id");
				double gpa = rs.getDouble("gpa");
				System.out.println("first name: " + fname + " " + "last name: " + lname + " " + "department id: "
						+ dept_id + " " + "gpa: " + gpa);

			}
		} catch (Exception e) {
			System.out.println("Unable to retrieve honors list");
		}
	}

}
