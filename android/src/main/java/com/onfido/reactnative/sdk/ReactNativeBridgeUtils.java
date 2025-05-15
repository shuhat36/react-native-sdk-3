package com.onfido.reactnative.sdk;

import java.lang.reflect.Field;
import java.util.Arrays;

import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import com.onfido.android.sdk.capture.config.DocumentMetadata;
import com.onfido.android.sdk.capture.config.MediaFile;
import com.onfido.android.sdk.capture.config.MediaResult;
import com.onfido.android.sdk.capture.config.MediaResult.DocumentResult;
import com.onfido.android.sdk.capture.config.MediaResult.LivenessResult;
import com.onfido.android.sdk.capture.config.MediaResult.SelfieResult;
import com.onfido.android.sdk.capture.ui.CaptureType;

/**
 * Utility methods for the SDK bridge.
 */
class ReactNativeBridgeUtiles {
    /**
     * This converts a simple object with public fields into WritableMap objects.
     * Specifically:
     * <ul>
     * <li>This does not convert arrays, Iterables, or any other complex object.</li>
     * <li>It does not use Java bean getters, or private, protected, or package fields.</li>
     * <li>This does not check for circular dependencies: A stack overflow error will occur if there are cycles.</li>
     * </ul>
     *
     * @param o The object to convert
     * @return The object values as nested WritableMaps
     * @throws Exception if there are any errors converting the object.
     */
    public static WritableMap convertPublicFieldsToWritableMap(Object o) throws IllegalAccessException {
        WritableMap map = Arguments.createMap();

        Field[] declaredFields = o.getClass().getFields(); // NOTE: getFields gets only the public fields.
        for (Field field : declaredFields) {
            String key = field.getName();
            Object value = field.get(o);
            if (value == null) {
                // noop: Don't add null properties to the map.
            } else if (value instanceof Iterable) {
                // noop: This is currently not supported.
            } else if (value instanceof Boolean) {
                map.putBoolean(key, (Boolean) value);
            } else if (value instanceof Integer) {
                map.putInt(key, (Integer) value);
            } else if (value instanceof Double) {
                map.putDouble(key, (Double) value);
            } else if (value instanceof String) {
                map.putString(key, (String) value);
            } else if (value instanceof Object) {
                map.putMap(key, convertPublicFieldsToWritableMap(value));
            }
        }
        return map;
    }

    // MediaFile attributes (as defined and expected in React)
    public static final String KEY_CAPTURE_TYPE = "captureType";
    public static final String KEY_FILE_DATA = "fileData";
    public static final String KEY_FILE_NAME = "fileName";
    public static final String KEY_FILE_TYPE = "fileType";
    // MediaFile#DocumentMetadata attributes (as defined and expected in React)
    public static final String KEY_DOCUMENT_SIDE = "side";
    public static final String KEY_DOCUMENT_TYPE = "type";
    public static final String KEY_DOCUMENT_ISSUING_COUNTRY = "issuingCountry";

    public static WritableMap getMediaResultMap(MediaResult mediaResult) {
        WritableMap map = Arguments.createMap();

        // Ugly Java code :(

        if (mediaResult instanceof DocumentResult) {
            DocumentResult documentResult = (DocumentResult) mediaResult;
            map.putString(KEY_CAPTURE_TYPE, CaptureType.DOCUMENT.name());

            MediaFile mediaFile = documentResult.getFileData();
            map.putString(KEY_FILE_DATA, Arrays.toString(mediaFile.getFileData()));
            map.putString(KEY_FILE_TYPE, mediaFile.getFileType());
            map.putString(KEY_FILE_NAME, mediaFile.getFileName());

            DocumentMetadata metadata = documentResult.getDocumentMetadata();
            map.putString(KEY_DOCUMENT_TYPE, metadata.getType());
            map.putString(KEY_DOCUMENT_SIDE, metadata.getSide());
            map.putString(KEY_DOCUMENT_ISSUING_COUNTRY, metadata.getIssuingCountry());

        } else if (mediaResult instanceof LivenessResult) {
            LivenessResult livenessResult = (LivenessResult) mediaResult;
            MediaFile mediaFile = livenessResult.getFileData();
            map.putString(KEY_FILE_DATA, Arrays.toString(mediaFile.getFileData()));
            map.putString(KEY_FILE_TYPE, mediaFile.getFileType());
            map.putString(KEY_FILE_NAME, mediaFile.getFileName());
            map.putString(KEY_CAPTURE_TYPE, CaptureType.VIDEO.name());

        } else if (mediaResult instanceof SelfieResult) {
            SelfieResult selfieResult = (SelfieResult) mediaResult;
            MediaFile mediaFile = selfieResult.getFileData();
            map.putString(KEY_FILE_DATA, Arrays.toString(mediaFile.getFileData()));
            map.putString(KEY_FILE_TYPE, mediaFile.getFileType());
            map.putString(KEY_FILE_NAME, mediaFile.getFileName());
            map.putString(KEY_CAPTURE_TYPE, CaptureType.FACE.name());
        }
        return map;
    }
}