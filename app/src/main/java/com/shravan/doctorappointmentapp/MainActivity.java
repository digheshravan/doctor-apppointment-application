package com.shravan.doctorappointmentapp;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import androidx.activity.EdgeToEdge;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.Query;
import com.google.firebase.database.ValueEventListener;
import android.widget.Toast;

import java.util.Objects;

public class MainActivity extends AppCompatActivity {

    TextView txt1;
    Button b1;
    EditText et1,et2;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_main);

        txt1 = findViewById(R.id.signup);
        et1 = findViewById(R.id.email);
        et2 = findViewById(R.id.password);
        b1 = findViewById(R.id.signin);

        b1.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(!validateUsername() | !validatePassword()){

                }else {
                    checkUser();
                }
            }
        });
        txt1.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent signupIntent = new Intent(MainActivity.this, SignUpActivity.class);
                startActivity(signupIntent);
            }
        });

    }
    public boolean validateUsername(){
        String val = et1.getText().toString();
        if (val.isEmpty()){
            et1.setError("Email cannot be empty");
            return false;
        }else {
            et1.setError(null);
            return true;
        }
    }
    public boolean validatePassword(){
        String val = et2.getText().toString();
        if (val.isEmpty()){
            et2.setError("Password cannot be empty");
            return false;
        }else {
            et2.setError(null);
            return true;
        }
    }
    public void checkUser() {
        String Semail = et1.getText().toString().trim();
        String Spassword = et2.getText().toString().trim();

        DatabaseReference reference = FirebaseDatabase.getInstance().getReference("users");

        reference.addListenerForSingleValueEvent(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                boolean found = false;
                for (DataSnapshot userSnapshot : snapshot.getChildren()) {
                    String emailFromDB = userSnapshot.child("email").getValue(String.class);
                    String passwordFromDB = userSnapshot.child("password").getValue(String.class);

                    if (emailFromDB != null && emailFromDB.equals(Semail)) {
                        found = true;
                        if (passwordFromDB != null && passwordFromDB.equals(Spassword)) {
                            // Login successful
                            et1.setError(null);
                            et2.setError(null);
                            Intent Loginintent = new Intent(MainActivity.this, LoggedIn.class);
                            startActivity(Loginintent);
                            finish();
                        } else {
                            et2.setError("Invalid Password");
                            et2.requestFocus();
                        }
                        break;
                    }
                }
                if (!found) {
                    et1.setError("User not found");
                    et1.requestFocus();
                }
            }
            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                Toast.makeText(MainActivity.this, "Database Error: " + error.getMessage(), Toast.LENGTH_SHORT).show();
            }
        });
    }

}