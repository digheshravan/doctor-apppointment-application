package com.shravan.doctorappointmentapp;

import android.os.Bundle;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;

public class LoggedIn extends AppCompatActivity {
    TextView t1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_loggedin);

        t1 = findViewById(R.id.txt);
        String email = getIntent().getStringExtra("email");
        t1.setText("Welcome, " + email);
    }
}
