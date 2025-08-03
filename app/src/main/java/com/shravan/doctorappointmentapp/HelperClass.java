package com.shravan.doctorappointmentapp;

public class HelperClass {
    String name, email, phoneno, password, gender;

    public HelperClass() {
        // Required no-argument constructor for Firebase
    }

    public HelperClass(String name, String phoneno, String email, String password, String gender) {
        this.name = name;
        this.phoneno = phoneno;
        this.email = email;
        this.password = password;
        this.gender = gender;
    }

    public String getName() {
        return name;
    }

    public String getPhoneno() {
        return phoneno;
    }

    public String getEmail() {
        return email;
    }

    public String getPassword() {
        return password;
    }

    public String getGender() {
        return gender;
    }

    public void setName(String name) {
        this.name = name;
    }

    public void setPhoneno(String phoneno) {
        this.phoneno = phoneno;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public void setGender(String gender) {
        this.gender = gender;
    }
}
