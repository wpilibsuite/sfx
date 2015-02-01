/*
 * Copyright (C) 2015 patrick
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package edu.wpi.first.sfx.designer.util;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;
import javafx.collections.ListChangeListener;
import javafx.collections.ObservableList;
import javafx.collections.transformation.TransformationList;

/**
 * Maps elements of type F to E with change listeners working as expected.
 * 
 * via https://javafx-jira.kenai.com/browse/RT-35741
 */
public class MappedList<E, F> extends TransformationList<E, F> {
    private final Function<F, E> mapper;
    private final ArrayList<E> mapped;

    /**
     * Creates a new MappedList list wrapped around the source list.
     * Each element will have the given function applied to it, such that the list is cast through the mapper.
     */
    public MappedList(ObservableList<? extends F> source, Function<F, E> mapper) {
        super(source);
        this.mapper = mapper;
        this.mapped = new ArrayList<>(source.size());
        mapAll();
    }

    private void mapAll() {
        mapped.clear();
        for (F val : getSource())
            mapped.add(mapper.apply(val));
    }

    @Override
    protected void sourceChanged(ListChangeListener.Change<? extends F> c) {
        // Is all this stuff right for every case? Probably it doesn't matter for this app.
        beginChange();
        while (c.next()) {
            if (c.wasPermutated()) {
                int[] perm = new int[c.getTo() - c.getFrom()];
                for (int i = c.getFrom(); i < c.getTo(); i++)
                    perm[i - c.getFrom()] = c.getPermutation(i);
                nextPermutation(c.getFrom(), c.getTo(), perm);
            } else if (c.wasUpdated()) {
                for (int i = c.getFrom(); i < c.getTo(); i++) {
                    remapIndex(i);
                    nextUpdate(i);
                }
            } else {
                if (c.wasRemoved()) {
                    // Removed should come first to properly handle replacements, then add.
                    List<E> removed = mapped.subList(c.getFrom(), c.getFrom() + c.getRemovedSize());
                    ArrayList<E> duped = new ArrayList<>(removed);
                    removed.clear();
                    nextRemove(c.getFrom(), duped);
                }
                if (c.wasAdded()) {
                    for (int i = c.getFrom(); i < c.getTo(); i++) {
                        mapped.addAll(c.getFrom(), c.getAddedSubList().stream().map(mapper).collect(Collectors.toList()));
                        remapIndex(i);
                    }
                    nextAdd(c.getFrom(), c.getTo());
                }
            }
        }
        endChange();
    }

    private void remapIndex(int i) {
        if (i >= mapped.size()) {
            for (int j = mapped.size(); j <= i; j++) {
                mapped.add(mapper.apply(getSource().get(j)));
            }
        }
        mapped.set(i, mapper.apply(getSource().get(i)));
    }

    @Override
    public int getSourceIndex(int index) {
        return index;
    }

    @Override
    public E get(int index) {
        return mapped.get(index);
    }

    @Override
    public int size() {
        return mapped.size();
    }
}