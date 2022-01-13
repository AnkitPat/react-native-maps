package com.airbnb.android.react.maps;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Environment;
import android.util.Log;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableArray;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.Tile;
import com.google.android.gms.maps.model.TileOverlay;
import com.google.android.gms.maps.model.TileOverlayOptions;
import com.google.android.gms.maps.model.TileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.util.ArrayList;

public class AirMapLocalTile extends AirMapFeature {

    class AIRMapLocalTileProvider implements TileProvider {
        private static final int BUFFER_SIZE = 16 * 1024;
        private int tileSize;
        private String pathTemplate;
        private String path;
        private String flavourName;


        public AIRMapLocalTileProvider(int tileSizet, String pathTemplate) {
            this.tileSize = tileSizet;
            this.pathTemplate = pathTemplate;

            try {


                SharedPreferences sh = getContext().getSharedPreferences("MySharedPref", Context.MODE_PRIVATE);

// The value will be default as empty string because for
// the very first time when the app is opened, there is nothing to show
                String storageType = sh.getString("storageType", "internal");
                ArrayList<File> files = getAllExternalFilesDirs();
                if (storageType.equals("external")) {


                    if (files.size() > 1)
                        this.path = files.get(1).getAbsolutePath();
                    else
                        this.path = getContext().getFilesDir().getAbsolutePath();

                } else {
                    this.path = getContext().getFilesDir().getAbsolutePath();
                }

                this.flavourName = getBuildConfigValue("VARIANT").toString().toUpperCase();
            } catch (Exception e) {

                AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
                builder.setMessage("There is some issue with storage on your device, please reinstall application. If issue persist, feedback@acsi.eu")
                        .setCancelable(false)
                        .setPositiveButton("Exit", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
//                                AirMapLocalTile.this.finish();
                                System.exit(0);
                            }
                        });

                AlertDialog alert = builder.create();
                alert.show();

            }
        }

        public ArrayList<File> getAllExternalFilesDirs(){
            File[] allExternalFilesDirs = getContext().getExternalFilesDirs(null);
            ArrayList<File> files = new ArrayList<>();
            for (File f : allExternalFilesDirs) {
                if (f != null) {
                    files.add(f);
                }
            }
           return files;
        }

        Object getBuildConfigValue(String fieldName) {
            try {
                Class c = Class.forName("eu.acsi.BuildConfig");
                Field f = c.getDeclaredField(fieldName);
                f.setAccessible(true);
                return f.get(null);
            } catch (Exception e) {
                e.printStackTrace();
                return null;
            }
        }

        @Override
        public Tile getTile(int x, int y, int zoom) {
            // TODO

            String path = this.path + "/data/" + this.flavourName + "/";
            Log.v("Check>>>", path);
            SQLiteDatabase database = SQLiteDatabase.openDatabase(path + "maptilesindex.sqlite", null, 0);
            String tileQuery = "SELECT PackageID FROM ZoomLevelTileRange WHERE ZoomLevel=? AND (? BETWEEN StartX And EndX) AND  (? BETWEEN StartY And EndY)";
            Cursor tileCursor = database.rawQuery(tileQuery, new String[]{zoom + "", x + "", y + ""});
            try {

                if (tileCursor.moveToFirst()) {
                    ArrayList<Integer> tileRows = new ArrayList<>();

                    do {
                        int tileRow = tileCursor.getInt(tileCursor.getColumnIndex("PackageID"));
                        Log.v("Check>>>", tileRow + "," + x + "," + y + "," + zoom + "," + tileCursor);
                        tileRows.add(tileRow);

                    } while (tileCursor.moveToNext());
                    tileCursor.close();
                    database.close();
                    for (Integer row :
                            tileRows) {
                        if (row == 0) {
                            SQLiteDatabase databaseMapTile = SQLiteDatabase.openDatabase(path + "maptiles.sqlite", null, 0);
                            String tileQueryMapTile = "SELECT ImageData FROM Tile WHERE ZoomLevel=? AND X=? and Y=?";
                            Cursor tileCursorMapTile = databaseMapTile.rawQuery(tileQueryMapTile, new String[]{zoom + "", x + "", y + ""});
                            try {
                                if (tileCursorMapTile.moveToFirst()) {
                                    if (!tileCursorMapTile.isAfterLast()) {
                                        byte[] tileData = tileCursorMapTile.getBlob(tileCursorMapTile.getColumnIndex("ImageData"));
                                        if (tileData != null) {
                                            Log.v("Check>>>", tileData.toString());
                                            byte[] image = tileData;
                                            return image == null ? TileProvider.NO_TILE : new Tile(this.tileSize, this.tileSize, image);

                                        }

                                    }

                                }
                            } catch (Exception e) {
                                e.printStackTrace();
                            } finally {
                                tileCursorMapTile.close();
                                databaseMapTile.close();
                            }
                        } else if (new File(path + "maptiles" + row + ".sqlite").exists()) {
                            SQLiteDatabase databaseMapTile = SQLiteDatabase.openDatabase(path + "maptiles" + row + ".sqlite", null, 0);
                            String tileQueryMapTile = "SELECT ImageData FROM Tile WHERE ZoomLevel=? AND X=? and Y=?";
                            Cursor tileCursorMapTile = databaseMapTile.rawQuery(tileQueryMapTile, new String[]{zoom + "", x + "", y + ""});
                            try {
                                if (tileCursorMapTile.moveToFirst()) {
                                    if (!tileCursorMapTile.isAfterLast()) {
                                        byte[] tileData = tileCursorMapTile.getBlob(tileCursorMapTile.getColumnIndex("ImageData"));
                                        if (tileData != null) {
                                            Log.v("Check>>>", tileData.toString());
                                            byte[] image = tileData;
                                            return image == null ? new Tile(this.tileSize, this.tileSize, readTileImage(this.path + "/data/no_maptiles1.png")) : new Tile(this.tileSize, this.tileSize, image);

                                        }

                                    }

                                }
                            } catch (Exception e) {
                                e.printStackTrace();
                            } finally {
                                tileCursorMapTile.close();
                                databaseMapTile.close();
                            }
                        }
                    }

                }
            } catch (Exception e) {
                Log.v("Check>>>", e.getMessage());
            } finally {
                tileCursor.close();
                database.close();
            }

            return new Tile(this.tileSize, this.tileSize, readTileImage(this.path + "/data/no_maptiles1.png"));
        }

        public void setPathTemplate(String pathTemplate) {
            this.pathTemplate = pathTemplate;
        }

        public void setTileSize(int tileSize) {
            this.tileSize = tileSize;
        }

        private byte[] readTileImage(String path) {
            InputStream in = null;
            ByteArrayOutputStream buffer = null;
            File file = new File(path);

            try {
                in = new FileInputStream(file);
                buffer = new ByteArrayOutputStream();

                int nRead;
                byte[] data = new byte[BUFFER_SIZE];

                while ((nRead = in.read(data, 0, BUFFER_SIZE)) != -1) {
                    buffer.write(data, 0, nRead);
                }
                buffer.flush();

                return buffer.toByteArray();
            } catch (IOException e) {
                e.printStackTrace();
                return null;
            } catch (OutOfMemoryError e) {
                e.printStackTrace();
                return null;
            } finally {
                if (in != null) try {
                    in.close();
                } catch (Exception ignored) {
                }
                if (buffer != null) try {
                    buffer.close();
                } catch (Exception ignored) {
                }
            }
        }

        private String getTileFilename(int x, int y, int zoom) {
            String s = this.pathTemplate
                    .replace("{x}", Integer.toString(x))
                    .replace("{y}", Integer.toString(y))
                    .replace("{z}", Integer.toString(zoom));
            return s;
        }
    }

    private TileOverlayOptions tileOverlayOptions;
    private TileOverlay tileOverlay;
    private AirMapLocalTile.AIRMapLocalTileProvider tileProvider;

    private String pathTemplate;
    private float tileSize;
    private float zIndex;

    public AirMapLocalTile(Context context) {
        super(context);
    }

    public void setPathTemplate(String pathTemplate) {
        this.pathTemplate = pathTemplate;
        if (tileProvider != null) {
            tileProvider.setPathTemplate(pathTemplate);
        }
        if (tileOverlay != null) {
            tileOverlay.clearTileCache();
        }
    }

    public void setZIndex(float zIndex) {
        this.zIndex = zIndex;
        if (tileOverlay != null) {
            tileOverlay.setZIndex(zIndex);
        }
    }

    public void setTileSize(float tileSize) {
        this.tileSize = tileSize;
        if (tileProvider != null) {
            tileProvider.setTileSize((int) tileSize);
        }
    }

    public TileOverlayOptions getTileOverlayOptions() {
        if (tileOverlayOptions == null) {
            tileOverlayOptions = createTileOverlayOptions();
        }
        return tileOverlayOptions;
    }

    private TileOverlayOptions createTileOverlayOptions() {
        TileOverlayOptions options = new TileOverlayOptions();
        options.zIndex(zIndex);
        this.tileProvider = new AirMapLocalTile.AIRMapLocalTileProvider((int) this.tileSize, this.pathTemplate);
        options.tileProvider(this.tileProvider);
        return options;
    }

    @Override
    public Object getFeature() {
        return tileOverlay;
    }

    @Override
    public void addToMap(GoogleMap map) {
        this.tileOverlay = map.addTileOverlay(getTileOverlayOptions());
    }

    @Override
    public void removeFromMap(GoogleMap map) {
        tileOverlay.remove();
    }
}
