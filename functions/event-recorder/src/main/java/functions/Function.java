package functions;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import io.quarkus.funqy.Funq;
import io.quarkus.funqy.knative.events.CloudEvent;
import io.quarkus.funqy.knative.events.CloudEventBuilder;
import io.quarkus.logging.Log;

/**
 * Your Function class
 */
public class Function {

    @ConfigProperty(name = "app.ce.path")
    String filepath;

    /**
     * Use the Quarkus Funq extension for the function. This example
     * function simply echoes its input data.
     * @param input a CloudEvent
     * @return a CloudEvent
     */
    @Funq
    public CloudEvent<Output> function(CloudEvent<Input> input) {
        try {
            writeToFile(input);
            Output output = new Output(input.data().getMessage() + " has been written to a file...");
            return CloudEventBuilder.create().build(output);
        } catch (Exception e) {
            Log.error("Error writing to file", e);
            Output output = new Output("Error writing the Cloud Event to a file...");
            return CloudEventBuilder.create().type("function.write.error").build(output);
        }
    }

    private void writeToFile(CloudEvent<Input> ce) throws IOException {
        File path = new File(filepath);
        if(!path.exists()){
            Log.info("Creating directories: " + filepath);
            path.mkdirs();
        }
        BufferedWriter writer = new BufferedWriter(new FileWriter(filepath + getFilename() + "-ce.txt", true));
		writer.write(ce.toString());
        writer.newLine();
        writer.close();
    }

    private String getFilename() {
        return System.getenv().getOrDefault("HOSTNAME", "default-pod");
    }

}