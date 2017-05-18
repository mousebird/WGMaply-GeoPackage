package com.mousebirdconsulting.wggpkg;

import android.support.v4.app.Fragment;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.widget.Button;
import android.view.View;
import android.os.Bundle;

import android.util.Log;

public class MainActivity extends AppCompatActivity implements GPkgTreeFragment.GPkgTreeFragmentInteractionListener {

    private EarthFragment earthFragment;
    private Button gpkgButton;

    private boolean viewTree = true;


    private GPkgTreeFragment gpkgTreeFragment;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Toolbar myToolbar = (Toolbar) findViewById(R.id.toolbar);
        setSupportActionBar(myToolbar);

        gpkgTreeFragment = new GPkgTreeFragment();
        earthFragment = new EarthFragment();

        gpkgButton = (Button) findViewById(R.id.gpkgbtn);
//        gpkgButton.setEnabled(false);
        setViewTree(true);
        gpkgButton.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                setViewTree(!viewTree);
//                selectFragment(gpkgTreeFragment);
//                gpkgButton.setEnabled(false);

            }
        });
    }



    private void selectFragment(Fragment fragment) {
        getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.content_frame, fragment)
                .commit();
    }

    private void setViewTree(boolean viewTree) {
        this.viewTree = viewTree;
        if (viewTree) {
            selectFragment(gpkgTreeFragment);
            gpkgButton.setText("GLOBE");
        } else {
            selectFragment(earthFragment);
            gpkgButton.setText("LAYERS");
        }
    }

    public void onFragmentInteraction() {
        Log.i("MainActivity", "onFragmentInteraction");
        //setViewTree(!viewTree);
//        selectFragment(earthFragment);
//        gpkgButton.setEnabled(true);
    }

}
