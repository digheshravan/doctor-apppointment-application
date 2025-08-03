package com.shravan.doctorappointmentapp;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;

import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

public class SignUpActivity extends AppCompatActivity {

    EditText etname, etphoneno, etemail, etpassword;
    RadioButton rb1, rb2;
    RadioGroup rg1;
    Button btn;
    TextView txt1, acc;
    FirebaseDatabase database;
    DatabaseReference reference;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_signup);

        // UI Bindings
        etname = findViewById(R.id.name);
        etphoneno = findViewById(R.id.phoneno);
        etemail = findViewById(R.id.email);
        etpassword = findViewById(R.id.password);
        rb1 = findViewById(R.id.rbmale);
        rb2 = findViewById(R.id.rbfemale);
        rg1 = findViewById(R.id.rgGender);
        btn = findViewById(R.id.signup);
        txt1 = findViewById(R.id.gender);
        acc = findViewById(R.id.signin);

        // Sign-up Button Listener
        btn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                String name = etname.getText().toString().trim();
                String phoneno = etphoneno.getText().toString().trim();
                String email = etemail.getText().toString().trim();
                String password = etpassword.getText().toString().trim();

                // Validate fields
                if (name.isEmpty() || phoneno.isEmpty() || email.isEmpty() || password.isEmpty()) {
                    Toast.makeText(SignUpActivity.this, "Please fill all fields", Toast.LENGTH_SHORT).show();
                    return;
                }

                int selectedId = rg1.getCheckedRadioButtonId();
                if (selectedId == -1) {
                    Toast.makeText(SignUpActivity.this, "Please select a gender", Toast.LENGTH_SHORT).show();
                    return;
                }

                RadioButton selectedRadioButton = findViewById(selectedId);
                String gender = selectedRadioButton.getText().toString();

                // Firebase connection
                database = FirebaseDatabase.getInstance();
                reference = database.getReference("users");

                HelperClass helperClass = new HelperClass(name, phoneno, email, password, gender);

                reference.child(phoneno).setValue(helperClass).addOnCompleteListener(task -> {
                    if (task.isSuccessful()) {
                        Toast.makeText(SignUpActivity.this, "You have signed up successfully!", Toast.LENGTH_SHORT).show();
                        Intent SignupIntent = new Intent(SignUpActivity.this,MainActivity.class);
                        startActivity(SignupIntent);
                        finish();
                    } else {
                        Toast.makeText(SignUpActivity.this, "Signup failed. Try again.", Toast.LENGTH_SHORT).show();
                    }
                });
            }
        });

        // Already have an account?
        acc.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                startActivity(new Intent(SignUpActivity.this, MainActivity.class));
            }
        });
    }
}
